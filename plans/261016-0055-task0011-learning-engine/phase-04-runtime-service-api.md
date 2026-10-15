# Phase 04 — LearnerAttemptService and LearnerAttemptController (Runtime API Surface)

## Context Links

- `docs/API_SPEC.md` §2 learner endpoints table + §4 security/idempotency (lines 52–57, 278–286)
- `docs/LEARNING_ENGINE_DESIGN.md` §3 runtime flow, §8 submit pseudocode
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LearnerLessonService.java` — pattern for loading + learner-safe payload
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/LearnerLessonController.java`
- `dau-viet-backend/src/main/java/com/dauviet/common/config/SecurityConfig.java` — `anyRequest().authenticated()` covers `/attempts/**` already; no new matchers needed unless choosing `permitAll` (we are not)
- V4 tables: `learner_attempts`, `activity_attempts` (used); `idempotency_records`, `lesson_results`, `user_evidence`, `reward_transactions` (deferred to TASK-0012)

## Overview

| Priority | Status | Effort |
|---|---|---|
| P0 | pending | 4h |

`LearnerAttemptService` orchestrates the submit transaction per LEARNING_ENGINE_DESIGN §8 (minus idempotency-record persistence, deferred). `LearnerAttemptController` exposes the minimal API surface needed to exercise the engine end-to-end: start attempt, read current activity, submit answer, read progress. Lesson completion is reported in the submit/progress responses but does NOT write `lesson_results` or flip `status` to `COMPLETED` — that lands with TASK-0012 (idempotent completion + rewards).

## Requirements

### Endpoints (all under `/api/v1`, authenticated user)

| Method | Path | Behavior |
|---|---|---|
| `POST` | `/lessons/{lessonId}/attempts` | Start or resume attempt pinned to `lessons.current_version_id`. If an `IN_PROGRESS` attempt exists for this user+version → return it (resume). Else create new `LearnerAttempt` (status `IN_PROGRESS`, `currentStageId` = snapshot entry, `currentActivityId` = first required activity of entry stage, `state_json` = empty `AttemptState`). Lesson must be `PUBLISHED` with `current_version_id` non-null (404 `LESSON_NOT_PUBLISHED`). |
| `GET` | `/attempts/{attemptId}` | Returns `{attemptId, lessonVersionId, status, currentStageId, currentActivityId, progress:{completedRequired,totalRequired}, completion:LessonCompletion}`. Owner only (403 `ATTEMPT_NOT_OWNER`). |
| `GET` | `/attempts/{attemptId}/current` | Learner-safe view of current activity: `{stage:{id,type,title}, activity:{id,type,instruction,config}, progress}`. Activity `config`/`feedback` passed through `LearnerProjectionService`. |
| `POST` | `/attempts/{attemptId}/activities/{activityId}/submissions` | Body = the `answer` JsonNode. Optional `Idempotency-Key` header (accepted but not persisted — deferred). Server validates: attempt owner; `IN_PROGRESS`; `activityId == currentActivityId` (409 `ACTIVITY_NOT_AVAILABLE` when stale — prevents skipping); handler exists; submit. On success: append `activity_attempts` row, update `state_json` (outputs + completedActivityIds + new cursor), save attempt. Returns `{status:"ACCEPTED", evaluation:ActivityResult, activityCompleted:bool, progress, next:{stageId,activityId}\|null, completion}`. |
| `POST` | `/attempts/{attemptId}/complete` | Checks `LessonCompletionEvaluator`; if `complete` → returns `{completion}` and **leaves status `IN_PROGRESS`** (transition deferred to TASK-0012). If not complete → 409 `ATTEMPT_NOT_IN_PROGRESS`-style code is wrong; use 422 `VALIDATION_ERROR` with details listing missing required activities. |

### Service internals (`LearnerAttemptService`)

`@Service` with `@Transactional` methods:

- `startOrResume(userId, lessonId)` — load lesson (must be `PUBLISHED`), find existing `IN_PROGRESS` attempt for `(userId, currentVersionId)` → return; else parse snapshot (via `SnapshotModel`) → build empty `AttemptState` with `currentStageId = entry`, `currentActivityId = firstRequired(entry)` → save.
- `getAttempt(userId, attemptId)` — load by `findByIdAndUserId`; ownership check.
- `getCurrent(userId, attemptId)` — attempt + pinned snapshot → resolve current activity → project via `LearnerProjectionService`.
- `submit(userId, attemptId, activityId, answer, idemKey)`:
  1. Load attempt `findForUpdate` (pessimistic lock).
  2. Verify `userId` ownership → `AttemptNotOwnedException`.
  3. Verify `status == IN_PROGRESS` → `AttemptNotInProgressException`.
  4. Load `LessonVersion` by `attempt.lessonVersionId`; parse `SnapshotModel`. (Snapshot is immutable — republishing cannot affect.)
  5. Verify `activityId == state.currentActivityId` → `ActivityNotAvailableException`.
  6. Lookup `ActivityHandler` via registry (throws `UnsupportedActivityTypeException` if missing).
  7. `handler.evaluate(ctx, submission)` — handler reads hidden keys from snapshot config, returns `ActivityResult` with learner-safe output.
  8. Update `AttemptState.outputs[activityId] = result.output`; add `activityId` to `completedActivityIds` iff `result.completed`.
  9. `attempt_no = activityAttempts.countByLearnerAttemptIdAndActivityId + 1`; insert `activity_attempts` row (submitted + result).
  10. Compute `next` via `StageTransitionResolver`; update `state.currentStageId`/`currentActivityId` (if next==null keep last).
  11. Evaluate `LessonCompletion` (returned to caller; does NOT flip status).
  12. Save attempt (`@Version` optimistic guard catches concurrent mutation; pessimistic lock serializes within tx).
- `complete(userId, attemptId)` — load + evaluate; return `LessonCompletion`. Does NOT write `lesson_results` (deferred).

### DTOs (`com.dauviet.learning.api.dto`)

- `AttemptStartResponse` — `{attemptId, lessonVersionId, status, resumed, currentStageId, currentActivityId}`
- `AttemptProgressResponse` — `{attemptId, lessonVersionId, status, progress:{completedRequired,totalRequired}, completion}`
- `CurrentActivityResponse` — `{stage:{id,type,title}, activity:{id,type,instruction,config}, progress}`
- `SubmitActivityRequest` — `{answer: JsonNode}` (wrapped so future metadata can be added)
- `SubmitActivityResponse` — `{status:"ACCEPTED", evaluation:{outcome,completed,output,feedbackCode}, activityCompleted, progress, next:{stageId,activityId}|null, completion}`

## Related Code Files

**Create**

- `dau-viet-backend/src/main/java/com/dauviet/learning/application/LearnerAttemptService.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/api/LearnerAttemptController.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/api/dto/{AttemptStartResponse,AttemptProgressResponse,CurrentActivityResponse,SubmitActivityRequest,SubmitActivityResponse}.java`

**Modify**

- None on controller surface. `SecurityConfig` already authenticates all `/api/v1/attempts/**` via `anyRequest().authenticated()` — verify with IT (anonymous → 401).

## Implementation Steps

1. Implement DTOs as Java records.
2. Implement `LearnerAttemptService` methods in the order listed. Reuse `ObjectMapper` for snapshot parse + `state_json` read/write.
3. Implement `LearnerAttemptController` delegating to service. `JWT subject` → `UUID.fromString(jwt.getSubject())`.
4. Verify ownership semantics — `findByIdAndUserId` returning empty maps to `AttemptNotFoundException` (404), while a found-attempt owned by another user maps to `AttemptNotOwnedException` (403). Decide which lookup to use (recommend: `findById`, then check `userId` field — gives distinct 403 vs 404, matching spec table).
5. Wire `Idempotency-Key` header through the submit signature; log it (without payload); do NOT persist.

## Todo List

- [ ] All five DTOs
- [ ] `LearnerAttemptService` — all five methods, `@Transactional` boundaries, pessimistic lock on submit
- [ ] `LearnerAttemptController` — four endpoints wired
- [ ] Verify anonymous requests get 401, learner role can call all four
- [ ] Submit on stale `activityId` → 409 `ACTIVITY_NOT_AVAILABLE`
- [ ] Submit on `COMPLETED` attempt → 409 `ATTEMPT_NOT_IN_PROGRESS` (note: TASK-0011 never flips to COMPLETED, but code path must exist for TASK-0012)
- [ ] Concurrent submit IT — two threads hit same attempt+activity; exactly one `activity_attempts` row for `attempt_no=1`; second sees `ACTIVITY_ALREADY_SUBMITTED` or serializes as `attempt_no=2`

## Success Criteria

- End-to-end IT: create PUBLISHED lesson → `POST /lessons/{id}/attempts` → `GET /attempts/{id}/current` returns first activity → `POST` correct MCQ answer → response `next` advances to next required activity → `POST /attempts/{id}/complete` on finished attempt returns `completion.complete=true`.
- Learner cannot read or submit another user's attempt (403).
- Submitting to activity other than `currentActivityId` → 409.
- No `LEARNER_HIDDEN_KEYS` anywhere in any response (dedicated IT assertion traverses response JSON).

## Risk Assessment

- **Cursor drift** — if client retries same submit while network was slow, server may have already advanced cursor. Mitigation: the request must target `currentActivityId`; once advanced, retry returns `ACTIVITY_NOT_AVAILABLE`. True idempotent replay needs TASK-0012's `idempotency_records`.
- **Transaction size** — submit does lock + read + write + insert in one tx; acceptable for MVP but flag if contention observed.
- **`minScore` semantics** — engine computes percentage of required activities done; BA may want weighted scoring. Recorded as open question.

## Security Considerations

- All endpoints authenticated; ownership enforced server-side.
- `GET /current` emits projected config only — hidden keys stripped by `LearnerProjectionService`.
- Submit answer is persisted raw in `submitted_answer_json` — free-text fields could contain offensive content; no moderation in scope (note for ops).
- `Idempotency-Key` header is logged at DEBUG level only, never the answer payload.

## Next Steps

- Phase 05: comprehensive tests (unit + IT).
