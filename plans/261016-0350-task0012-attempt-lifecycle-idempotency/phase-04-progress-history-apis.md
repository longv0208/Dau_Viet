# Phase 04 — Progress & History APIs

## Context

- Brief §4: "current in-progress attempts, completed attempt history, lesson
  completion results (`GET /attempts/{id}/result` per API_SPEC), progress
  summaries, resume info for mobile. Pagination per existing conventions
  (page/size, like GET /events). Owner-only data, no answer keys."
- API_SPEC §2 lists `GET /attempts/{attemptId}/result` and `GET /me/progress`
  as planned.
- `PageResponse<T>` is the existing envelope.

## Endpoints

All under `/api/v1`, owner-only (`@AuthenticationPrincipal Jwt` →
`jwtSubjectExtractor.userId(jwt)`).

| Method | Path | Response |
|---|---|---|
| `GET` | `/attempts/{attemptId}/result` | `AttemptResultResponse` — `404 RESULT_NOT_FOUND` until completed |
| `GET` | `/me/attempts?status=&page=&size=` | `PageResponse<AttemptSummaryDto>` |
| `GET` | `/me/progress` | `ProgressSummaryResponse` — mobile resume surface |

### `GET /attempts/{attemptId}/result`

```
200 AttemptResultResponse
404 ATTEMPT_NOT_FOUND          (attempt missing)
403 ATTEMPT_NOT_OWNER          (not owner)
404 RESULT_NOT_FOUND           (attempt exists, not completed yet)
```

`AttemptResultResponse`:

```java
public record AttemptResultResponse(
        UUID attemptId,
        UUID lessonId,
        UUID lessonVersionId,
        Integer versionNo,
        String status,           // "COMPLETED"
        double score,
        Instant startedAt,
        Instant completedAt,
        JsonNode result          // parsed lesson_results.result_json
) {}
```

`lessonId`/`versionNo` resolved via `LessonVersionRepository` join on
`lesson_version_id`.

### `GET /me/attempts`

Query params: `status` (optional, `IN_PROGRESS|COMPLETED|ABANDONED`; invalid →
400 VALIDATION_ERROR), `page` (default 0), `size` (default 20, cap 100).

Uses `LearnerAttemptRepository.findByUser[AndStatus]` returning `Page`.
Order: `last_active_at DESC` (most recent first — mobile "resume latest").

`AttemptSummaryDto`:

```java
public record AttemptSummaryDto(
        UUID attemptId,
        UUID lessonId,
        String lessonTitle,
        UUID lessonVersionId,
        Integer versionNo,
        String status,
        Instant startedAt,
        Instant lastActiveAt,
        Instant completedAt,
        AttemptProgressResponse.Progress progress,   // from state_json
        Double score                                 // null when not completed
) {}
```

Note on `lessonTitle`: requires join to `lessons` via `lesson_versions`. JPQL
constructor expression or projection interface — pick projection (simpler):

```java
public interface AttemptSummaryView {
    UUID getId(); UUID getLessonId(); String getLessonTitle();
    UUID getLessonVersionId(); Integer getVersionNo(); String getStatus();
    Instant getStartedAt(); Instant getLastActiveAt(); Instant getCompletedAt();
    String getStateJson();
}
```

`getStateJson` parsed → `Progress` via `SnapshotModel` + `AttemptState` (reuse
`progressOf`). `score` from `lesson_results` when status=COMPLETED (left join
or secondary fetch — secondary fetch is simpler: per-row
`results.findByLearnerAttemptId`, fine for `size≤100`).

### `GET /me/progress`

Non-paged mobile resume summary:

```java
public record ProgressSummaryResponse(
        List<AttemptSummaryDto> inProgress,    // status=IN_PROGRESS, last_active_at desc, cap 50
        long completedCount,
        long totalAttempts
) {}
```

Cap `inProgress` at 50 (no real user will have more; bounded unique constraint
effectively makes this a short list). Rationale: mobile app wants "what was I
doing" — one roundtrip.

## No answer keys

`AttemptSummaryDto` includes only cursor + counts. `AttemptResultResponse.result`
exposes `result_json` = `{completion:{complete,reason,detail}, progress:{…}}` —
both learner-safe (verdict + counts, no answer data). `assertNoHiddenKeys`
checks run in ITs.

## Controllers

Place in existing `LearnerAttemptController` (`/attempts/{id}/result`) and a
new `MeAttemptsController` (`/me/attempts`, `/me/progress`) — keeps `/me/**`
routes grouped, consistent with `/users/me` precedent.

## Files

- Modify `LearnerAttemptController` (add `/result`)
- New `api/MeAttemptsController.java`
- New `api/dto/AttemptResultResponse.java`
- New `api/dto/AttemptSummaryDto.java`
- New `api/dto/ProgressSummaryResponse.java`
- Modify `LearnerAttemptRepository` (paged finders via join projection)
- Modify `LearnerAttemptService` (add `getResult`, `listAttempts`, `getProgressSummary`)

## Tests

- `AttemptHistoryIT.resultBeforeComplete_404ResultNotFound`
- `AttemptHistoryIT.resultAfterComplete_200_withScoreAndJson`
- `AttemptHistoryIT.result_otherUser_403`
- `AttemptHistoryIT.listAttempts_pagedAndFiltered`: create 3 attempts across
  2 lessons (1 completed v1 + 1 in-progress v2 + 1 in-progress on another
  lesson) → `?status=IN_PROGRESS` returns 2, `?status=COMPLETED` returns 1,
  sorted lastActiveAt desc, pagination works (`size=1&page=1`).
- `AttemptHistoryIT.meProgress_returnsInProgressAndCount`
- `AttemptHistoryIT.noHiddenKeys_inListOrResult` — reuse `assertNoHiddenKeys`
  traversal on both responses.
- `AttemptHistoryIT.anonymous_401` on all three endpoints.

## Acceptance criteria

- AC: "`GET /attempts/{id}/result` returns persisted score + result_json for
  completed attempts, 404 RESULT_NOT_FOUND otherwise; owner-only."
- AC: "`GET /me/attempts` supports `status` filter + `page/size` per PageResponse
  convention; owner-scoped."
- AC: "`GET /me/progress` returns in-progress list + completedCount for mobile
  resume."
- AC: "No endpoint leaks `LEARNER_HIDDEN_KEYS` or other users' data."
