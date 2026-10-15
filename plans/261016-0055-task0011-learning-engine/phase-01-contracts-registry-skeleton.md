# Phase 01 — Runtime Contracts, Snapshot Model, ActivityHandler Registry Skeleton

## Context Links

- `docs/LEARNING_ENGINE_DESIGN.md` §5 (Java contracts proposal), §6 (handler catalog), §7 (attempt state)
- `docs/DATABASE_DESIGN.md` learner runtime tables (V4)
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/{ActivityType,StageType,DraftSchema,ActivityConfigValidator}.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/validators/AbstractActivityValidator.java` — mirror handler-per-type pattern
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/SnapshotBuilder.java` — snapshot_json shape authority
- `dau-viet-backend/src/main/java/com/dauviet/common/error/{ErrorCode,GlobalExceptionHandler}.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LearnerProjectionService.java` — reuse for learner-safe emission
- V4 migration `dau-viet-backend/src/main/resources/db/migration/V4__learner_runtime_progress_rewards.sql`

## Overview

| Priority | Status | Effort |
|---|---|---|
| P0 | pending | 3h |

Lay the engine foundation: typed runtime contracts shared by handlers and resolvers, an in-memory `SnapshotModel` parsed once per attempt from `snapshot_json`, a Spring `ActivityHandler` registry that mirrors `DraftValidator`'s per-type validator pattern, plus the engine exceptions and error codes needed downstream. No business evaluation yet — handlers are stubs that throw `UnsupportedOperationException` (replaced in phase 02).

## Key Insights

- `snapshot_json` already stores hidden keys verbatim (correctOptionIds, expectedOrder, …) because the server needs them for evaluation. The engine reads them from the snapshot but must never emit them — strip on the way out, not on the way in.
- `DraftValidator`'s registry constructor (`List<ActivityConfigValidator>` → `EnumMap`) is the pattern to clone: duplicate-bean guard at startup, `EnumMap` for O(1) lookup, `supports()` method on each handler.
- Attempt cursor is server-computed, never client-supplied (`LEARNING_ENGINE_DESIGN.md` §7).
- `learner_attempts.state_json` is a JSONB free-form column — the engine owns the schema; define a narrow `state` shape so TASK-0012 can extend it.

## Requirements

### Runtime contracts (all under `com.dauviet.learning.contract`)

- `AttemptContext` — `UUID attemptId`, `UUID userId`, `UUID lessonVersionId`, `String activityId`, `String stageId`, `JsonNode pinnedSnapshot` (read-only handle), `Map<String,JsonNode> priorOutputsByActivityId` (derived from `state_json`).
- `ActivitySubmission` — `UUID attemptId`, `String activityId`, `JsonNode answer`, `String idempotencyKey` (may be null).
- `ActivityResult` — `String outcome` (`COMPLETED`, `PARTIAL`, `INCORRECT`, `ACKNOWLEDGED`, `SUPPORTED`, `CONTRADICTED`, …), `boolean completed`, `JsonNode output` (learner-safe), `String feedbackCode` (references `feedback` key inside activity config, never the answer).
- `StageProgress` — `String stageId`, `List<String> requiredActivityIds`, `List<String> completedRequiredActivityIds`, `boolean complete`.
- `NextActivity` — `String stageId`, `String activityId`, `String activityType`, `JsonNode learnerConfig` (already projected).
- `NextStage` — `String stageId`, `String stageType`, `String reason` (`FORWARD`, `REVISE`, `RESTART_REQUIRED`, …).
- `LessonCompletion` — `boolean complete`, `String reason` (`ALL_REQUIRED_STAGES`, `REQUIRED_STAGE_IDS`, `MIN_SCORE`, `NOT_COMPLETE`), `JsonNode detail` (learner-safe).

### Snapshot model (`com.dauviet.learning.snapshot`)

- `SnapshotModel` — wraps parsed `snapshot_json`; indexes `stages` by id and `activities` by id; exposes `entryStageId` (stages[0]), `completion` node, and `evidenceById`/`assetById` maps for handler lookups.
- `SnapshotParseException` — thrown on missing required top-level fields or non-array `stages`; mapped to 500 `SNAPSHOT_CORRUPT` (existing `SnapshotCorruptException` semantics — either reuse it or have `SnapshotParseException` extend the lesson-domain exception so `GlobalExceptionHandler` mapping stays put).

### Handler SPI (`com.dauviet.learning.handler`)

- `ActivityHandler` interface — `ActivityType supports()` + `ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub)`. No reflection; pure function over the pinned snapshot. Signature mirrors `LEARNING_ENGINE_DESIGN.md` §5.
- `ActivityHandlerRegistry` — `@Component` built from `List<ActivityHandler>`; fails fast at startup on duplicate `supports()` or missing a `ActivityType`; lookup method throws `UnsupportedActivityTypeException` (new domain exception → 422 `UNSUPPORTED_ACTIVITY_TYPE` envelope).
- `AbstractActivityHandler` — shared helpers: `configOf(activity)`, `requireArray(answer, field)`, `readIds(answer, field)`, `feedbackFor(activity, outcome)`, `stripForLearner(JsonNode)` (delegates to `LearnerProjectionService`).

### Attempt domain model (`com.dauviet.learning.domain`)

- `LearnerAttempt` JPA entity — maps `learner_attempts` table; `@Id UUID`, `@Version Long rowVersion`, `@JdbcTypeCode(SqlTypes.JSON)` for `state_json`. Constructor + getters only; mutators explicit (`markCompleted`, `recordProgress`).
- `ActivityAttempt` JPA entity — maps `activity_attempts`; insert-only (no mutators).
- `LearnerAttemptStatus` enum — `IN_PROGRESS, COMPLETED, ABANDONED`.
- `AttemptState` value type wrapping `state_json` — fields: `Set<String> completedActivityIds`, `Map<String,JsonNode> outputs`, `String currentStageId`, `String currentActivityId`. Serializes to/from `ObjectNode`.

### Repositories (`com.dauviet.learning.infrastructure.persistence`)

- `LearnerAttemptRepository` — `findByIdAndUserId`, `findActiveForUserAndVersion(userId, versionId)`, `findForUpdate(id)` with `@Lock(PESSIMISTIC_WRITE)`.
- `ActivityAttemptRepository` — `countByLearnerAttemptIdAndActivityId`, `save`, `findByLearnerAttemptIdOrderByCreatedAt`.

### Error codes / exceptions

- New `ErrorCode`s (add to enum, keep alphabetical-ish): `ATTEMPT_NOT_FOUND`, `ATTEMPT_NOT_OWNER`, `ATTEMPT_NOT_IN_PROGRESS`, `ACTIVITY_NOT_AVAILABLE`, `ATTEMPT_ALREADY_COMPLETED`, `ACTIVITY_ALREADY_SUBMITTED` (reused on unique-violation retry), `SNAPSHOT_INVALID_FOR_ACTIVITY` (malformed activity definition inside snapshot), `LESSON_VERSION_MISMATCH`.
- New exceptions under `com.dauviet.learning.domain`: `AttemptNotFoundException`, `AttemptNotOwnedException`, `AttemptNotInProgressException`, `ActivityNotAvailableException`, `AttemptAlreadyCompletedException`, `UnsupportedActivityTypeException`, `SnapshotInvalidForActivityException`, `LessonVersionMismatchException`.
- `GlobalExceptionHandler` mappings: `ATTEMPT_NOT_FOUND`/`ACTIVITY_NOT_AVAILABLE` → 404; `ATTEMPT_NOT_OWNER` → 403; `ATTEMPT_NOT_IN_PROGRESS`, `ATTEMPT_ALREADY_COMPLETED`, `LESSON_VERSION_MISMATCH`, `ACTIVITY_ALREADY_SUBMITTED` → 409; `UNSUPPORTED_ACTIVITY_TYPE`, `SNAPSHOT_INVALID_FOR_ACTIVITY` → 422.

## Related Code Files

**Create**

- `dau-viet-backend/src/main/java/com/dauviet/learning/contract/AttemptContext.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/contract/ActivitySubmission.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/contract/ActivityResult.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/contract/StageProgress.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/contract/NextActivity.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/contract/NextStage.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/contract/LessonCompletion.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/snapshot/SnapshotModel.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/snapshot/SnapshotParseException.java` (or reuse `SnapshotCorruptException` — decide, see below)
- `dau-viet-backend/src/main/java/com/dauviet/learning/handler/ActivityHandler.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/handler/ActivityHandlerRegistry.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/handler/AbstractActivityHandler.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/domain/LearnerAttempt.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/domain/ActivityAttempt.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/domain/LearnerAttemptStatus.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/domain/AttemptState.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/domain/{AttemptNotFoundException,AttemptNotOwnedException,AttemptNotInProgressException,ActivityNotAvailableException,AttemptAlreadyCompletedException,UnsupportedActivityTypeException,SnapshotInvalidForActivityException,LessonVersionMismatchException}.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/infrastructure/persistence/LearnerAttemptRepository.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/infrastructure/persistence/ActivityAttemptRepository.java`

**Modify**

- `dau-viet-backend/src/main/java/com/dauviet/common/error/ErrorCode.java` — add codes listed above
- `dau-viet-backend/src/main/java/com/dauviet/common/error/GlobalExceptionHandler.java` — add handlers for new exceptions

## Implementation Steps

1. Add new `ErrorCode` enum constants.
2. Create `LearnerAttempt` + `ActivityAttempt` JPA entities + `LearnerAttemptStatus` + `AttemptState`. Keep `state_json` shape minimal and documented in class javadoc.
3. Create repositories. `findForUpdate` uses `@Lock(PESSIMISTIC_WRITE)` (same pattern as `LessonRepository.findForUpdate` added in TASK-0010).
4. Create `SnapshotModel` constructor that takes `JsonNode snapshot` (already parsed by `ObjectMapper.readTree`); builds `Map<String,JsonNode> stageById` / `activityById` / `evidenceById` / `assetById`. Throws `SnapshotParseException` on missing/invalid shape — decide whether to reuse `SnapshotCorruptException` (preferred: same 500 contract) or introduce new exception; document the choice.
5. Create `ActivityHandler` SPI + `AbstractActivityHandler` helpers + `ActivityHandlerRegistry` bean; assert startup fails on duplicate supports() (unit test).
6. Create all runtime contract records. No business logic yet.
7. Stub 12 handler beans (one per `ActivityType`) that implement `ActivityHandler` and return `throw new UnsupportedOperationException()` — these are placeholders replaced in phase 02. Each is a `@Component` so the registry is complete at wiring time.
8. Wire `GlobalExceptionHandler` handlers for new exceptions.

## Todo List

- [ ] `ErrorCode` enum updated
- [ ] `LearnerAttempt`/`ActivityAttempt` entities + `AttemptState` value type + `LearnerAttemptStatus` enum
- [ ] `LearnerAttemptRepository` + `ActivityAttemptRepository` interfaces
- [ ] `SnapshotModel` + parse/lookup methods + unit test
- [ ] `ActivityHandler` + `ActivityHandlerRegistry` + `AbstractActivityHandler`
- [ ] All 12 handler stubs (one per type) — registry startup completeness verified
- [ ] All runtime contract records
- [ ] All new exceptions + `GlobalExceptionHandler` mappings
- [ ] Unit test: `ActivityHandlerRegistryTest` — duplicate support fails startup, lookup returns handler, unknown type → `UnsupportedActivityTypeException`
- [ ] Unit test: `AttemptStateTest` — round-trip serialize/deserialize

## Success Criteria

- `mvnw -pl dau-viet-backend compile` exits 0.
- `ActivityHandlerRegistry` boots with all 12 types registered; test verifies `handler.supports()` returns a distinct type per bean.
- `SnapshotModel` accepts the fixture JSON used by `AdminLessonPublishIT.publishableDraft` and resolves activity lookups.
- `GlobalExceptionHandler` returns the documented code+status for each new exception (covered by `ControllerExceptionIT` slice or existing pattern).

## Risk Assessment

- **Entity mapping mismatch with V4 DDL** — verify `row_version` uses `@Version`, `state_json` uses `JsonNode` via `@JdbcTypeCode(SqlTypes.JSON)`, `chk_attempt_state` CHECK (must always be object) enforced by `AttemptState` never producing null.
- **`SnapshotModel` too permissive** — strict-shape parse catches corrupt snapshots early instead of NPE deep in a handler.
- **Registry partial wiring** — startup-time check prevents shipping a missing type silently.

## Security Considerations

- Contracts are pure value types; they cannot leak hidden keys by accident — but handlers MUST still strip when constructing `ActivityResult.output`/`feedback` (enforced in phase 02 via shared helper).
- `AttemptState` is server-internal; never serialize directly to learner payload — public DTOs built in phase 04.

## Next Steps

- Phase 02: implement all 12 handler bodies.
