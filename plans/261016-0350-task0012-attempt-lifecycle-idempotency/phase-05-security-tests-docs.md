# Phase 05 — Security Hardening, Tests, Docs

## 5a. Malformed JWT subject → 401

Currently every controller does `UUID.fromString(jwt.getSubject())` — throws
`IllegalArgumentException` → mapped by `GlobalExceptionHandler` to 400
`VALIDATION_ERROR`. UserController already catches and converts to
`AuthenticationFailedException` (→ 401 `INVALID_CREDENTIALS`). Brief asks:
"malformed JWT subject → controlled 401".

Refactor: extract the UserController pattern into a shared helper.

`com.dauviet.common.security.JwtSubjectExtractor` (new):

```java
@Component
public class JwtSubjectExtractor {
    public UUID userId(Jwt jwt) {
        try {
            return UUID.fromString(jwt.getSubject());
        } catch (RuntimeException ex) {
            throw new AuthenticationFailedException();
        }
    }
}
```

Update callers:
- `LearnerAttemptController` — replace `userId()` private method
- `UserController` — replace `subjectToUuid` body
- `MeAttemptsController` (new) — use it
- Admin controllers (`AdminLessonController`, `AdminLessonDraftController`,
  `AdminEvidenceController`) — same try/catch replacement (minor refactor,
  DRY)

IT: forge a token with non-UUID subject. `JwtTokenService.createAccessToken`
uses `u.getId().toString()` — for the test, hand-craft a JWT via
`NimbusJwtEncoder` or expose a test helper. Alternative cheaper test: unit
test `JwtSubjectExtractor` directly + one IT on `/users/me` using a custom
JWT (may need `JwtDecoder` bean injection in test — or mock).
Choose: unit test for extractor + spy on `JwtAuthenticationConverter` is
overkill — do **one IT** that crafts a bad-subject JWT with the same signing
secret via the `JwtEncoder` bean (already in context for resource server).

## 5b. Test plan (brief §9)

### New IT files (all under `dau-viet-backend/src/test/java/com/dauviet/learning/`)

- `ResumeAcrossRepublishIT` — phase-01 scenarios
- `AttemptCompletionIT` — phase-02 scenarios
- `IdempotencyIT` — phase-03 scenarios
- `AttemptHistoryIT` — phase-04 endpoints
- `MalformedSubjectIT` — bad-subject JWT → 401 on `/users/me` + `/attempts/...`
- Extend `LearnerAttemptApiIT`: submit-after-complete → 409
  `ATTEMPT_ALREADY_COMPLETED`; concurrent start → one attempt
- Extend `LearnerAttemptConcurrencyIT`: concurrent complete → exactly one
  `lesson_results` row; concurrent same-key submit → single `activity_attempts`
  insert OR clean replay

### New unit tests

- `IdempotencyServiceTest` — hash determinism, payload-mismatch branch,
  replay deserialization, no-key passthrough, unique-violation path
- `JwtSubjectExtractorTest` — valid UUID, malformed, null subject
- `CompleteAttemptResponseTest` — serialization shape (or rely on IT)

### Fixture updates

- `AttemptItFixture` — add `submitWithKey(...)`, `complete(...)` helpers
- `AbstractPostgresIT.clearAuthoringTables` — add `delete from
  lesson_results` + `delete from idempotency_records` (FK order:
  `idempotency_records` before `learner_attempts`? no FK to attempts — only
  users. `lesson_results` has FK to attempts → delete before
  `learner_attempts`).

### Coverage target

Maintain 129/129 green + new tests. Run `mvnw verify` once per phase after
phase-01; tester agent does final sweep.

## 5c. Docs updates

### `docs/API_SPEC.md`

- Mark `POST /attempts/{id}/complete` row as flipping status + writing
  `lesson_results` (TASK-0012).
- Add rows: `GET /attempts/{attemptId}/result`, `GET /me/attempts`,
  `GET /me/progress`.
- New section "Notes đã chốt TASK-0012" listing: complete flips + result
  contract; idempotency persistence + hash + conflict; resume-by-lesson;
  `IDEMPOTENCY_CONFLICT`/`ATTEMPT_NOT_COMPLETE`/`RESULT_NOT_FOUND` codes;
  score formula; TTL=24h config; submit-on-completed →
  `ATTEMPT_ALREADY_COMPLETED`.

### `docs/LEARNING_ENGINE_DESIGN.md`

- §7 state machine — annotate `COMPLETED` transition implemented in TASK-0012
  (atomic flip + lesson_results).
- §8 submit transaction — replace "check idempotency key" step with
  implemented behavior + hash formula + replay path.
- New §13 row/section "Lifecycle đã chốt (TASK-0012)" — resume-by-lesson,
  one-active-attempt-per-lesson (service-enforced), score formula, idempotency
  TTL policy.
- §14 Open decisions — remove resolved items, note open questions (rewards,
  ABANDONED policy, replay of expired records).

### `docs/DATABASE_DESIGN.md`

- Confirm `idempotency_records` semantics (payload conflict → 409, TTL).
- Document `score` semantics + `result_json` shape for `lesson_results`.
- No schema change needed — explicitly note "TASK-0012 required no migration;
  all tables/columns already present from V4."

### `docs/PROGRESS.md` — generated, no manual edit

### `tasks/TASK-0012/`

- `task.json` (per TASK-0011 format, `status:"in-progress"`, risk `high-risk`,
  deps `["TASK-0011"]`, planPath → this dir, acceptanceCriteria from phases)
- `brief.md` — 1-paragraph echo of goal + deliverables + out-of-scope.

## task.json skeleton (draft)

```json
{
  "schemaVersion": 1,
  "id": "TASK-0012",
  "type": "feature",
  "risk": "high-risk",
  "status": "in-progress",
  "goal": "Finalize learner attempt lifecycle: complete flips status + writes lesson_results atomically; persistent Idempotency-Key on submit+complete; resume by lesson across republish; progress/history/result endpoints; owner+JWT hardening.",
  "owner": "claude",
  "modules": ["backend"],
  "scope": ["dau-viet-backend/", "tasks/TASK-0012/", "docs/API_SPEC.md",
            "docs/LEARNING_ENGINE_DESIGN.md", "docs/DATABASE_DESIGN.md",
            "plans/261016-0350-task0012-attempt-lifecycle-idempotency/"],
  "acceptanceCriteria": [
    {"id":"AC-1","text":"POST /attempts/{id}/complete atomically flips status to COMPLETED + writes lesson_results (score, result_json, completed_at); refused incomplete → 409 ATTEMPT_NOT_COMPLETE; replayed → 200 stored response."},
    {"id":"AC-2","text":"Completed attempts reject submit with 409 ATTEMPT_ALREADY_COMPLETED; ABANDONED → ATTEMPT_NOT_IN_PROGRESS."},
    {"id":"AC-3","text":"Idempotency-Key on submit+complete persists idempotency_records (user+operation+key) in same tx; same key+same payload replays stored response; same key+different payload → 409 IDEMPOTENCY_CONFLICT; concurrent same-key cannot double-write."},
    {"id":"AC-4","text":"Resume: in-progress attempt on superseded lesson version resumes via POST /lessons/{id}/attempts (pinned version kept); completed attempt allows fresh start on current version."},
    {"id":"AC-5","text":"GET /attempts/{id}/result returns score + result_json for completed attempts (404 RESULT_NOT_FOUND otherwise); owner-only."},
    {"id":"AC-6","text":"GET /me/attempts supports status filter + page/size PageResponse; GET /me/progress returns in-progress + completedCount; owner-scoped, no hidden keys."},
    {"id":"AC-7","text":"Malformed JWT subject → 401 INVALID_CREDENTIALS on all learner endpoints (shared JwtSubjectExtractor)."},
    {"id":"AC-8","text":"Tests: unit coverage for idempotency hash/replay + extractor; Postgres ITs for completion lifecycle, idempotency, resume-across-republish, history pagination, ownership, no-hidden-keys, concurrency; prior 129 tests stay green."},
    {"id":"AC-9","text":"Docs updated: API_SPEC (endpoints + error codes + TASK-0012 notes), LEARNING_ENGINE_DESIGN §7/§8/§13/§14, DATABASE_DESIGN (no-migration note), task.json evidence."}
  ],
  "dependencies": ["TASK-0011"],
  "planPath": "plans/261016-0350-task0012-attempt-lifecycle-idempotency/plan.md"
}
```

## File checklist

**Modify:**
- `learning/application/LearnerAttemptService.java`
- `learning/api/LearnerAttemptController.java`
- `learning/infrastructure/persistence/LearnerAttemptRepository.java`
- `common/error/ErrorCode.java` — add `IDEMPOTENCY_CONFLICT`,
  `ATTEMPT_NOT_COMPLETE`, `RESULT_NOT_FOUND`
- `common/error/GlobalExceptionHandler.java` — map new exceptions
- `user/api/UserController.java` — use `JwtSubjectExtractor`
- `lesson/api/AdminLessonController.java`, `AdminLessonDraftController.java`,
  `AdminEvidenceController.java` — same
- `dau-viet-backend/src/main/resources/application.yml` — `app.learning.idempotency-ttl`
- `test/AbstractPostgresIT.java` — extend cleanup
- `test/learning/AttemptItFixture.java` — helpers
- `test/learning/LearnerAttemptApiIT.java` — extend
- `docs/API_SPEC.md`, `docs/LEARNING_ENGINE_DESIGN.md`,
  `docs/DATABASE_DESIGN.md`

**Create:**
- `learning/domain/LessonResult.java`
- `learning/domain/IdempotencyRecord.java`
- `learning/domain/IdempotencyConflictException.java`
- `learning/domain/AttemptNotCompleteException.java`
- `learning/domain/ResultNotFoundException.java`
- `learning/infrastructure/persistence/LessonResultRepository.java`
- `learning/infrastructure/persistence/IdempotencyRecordRepository.java`
- `learning/application/IdempotencyService.java`
- `learning/api/MeAttemptsController.java`
- `learning/api/dto/CompleteAttemptResponse.java`
- `learning/api/dto/AttemptResultResponse.java`
- `learning/api/dto/AttemptSummaryDto.java`
- `learning/api/dto/ProgressSummaryResponse.java`
- `common/security/JwtSubjectExtractor.java`
- Test files: `ResumeAcrossRepublishIT`, `AttemptCompletionIT`,
  `IdempotencyIT`, `AttemptHistoryIT`, `MalformedSubjectIT`,
  `IdempotencyServiceTest`, `JwtSubjectExtractorTest`
- `tasks/TASK-0012/task.json`, `tasks/TASK-0012/brief.md`

**No new files:** No V7 migration required.
