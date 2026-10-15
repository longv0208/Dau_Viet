# Phase 06 — Tests

## Context links
- `dau-viet-backend/src/test/java/com/dauviet/AbstractPostgresIT.java` (shared Testcontainers Postgres)
- `dau-viet-backend/src/test/java/com/dauviet/lesson/AdminLessonIT.java` (cleanup pattern: `session_replication_role=replica` to bypass immutable trigger)
- `dau-viet-backend/src/test/java/com/dauviet/historicalevent/admin/AdminEventIT.java` (auth/setup conventions)

## Overview
- Priority: P1
- Status: pending
- JUnit5 + MockMvc ITs against real Postgres (Testcontainers). Pure unit tests for `DraftValidator` + per-type validators (no Spring context, fast).

## Test matrix per AC

### AC coverage (proposed, mirrors task.json)

| AC | Tests |
|---|---|
| AC-1 stage CRUD + reorder + transitions | `AdminLessonStageIT.addStage_created`, `patchStage_updatesFields`, `deleteStage_removesAndPrunesNextStageIds`, `reorderStages_appliesNewOrder`, `reorderStages_staleRowVersion_409`, `addStage_danglingNextStage_422`, `addStage_selfLoop_422`, `addStage_unknownType_422` |
| AC-2 activity CRUD + reorder + allow-list | `AdminLessonActivityIT.addActivity_created`, `addActivity_wrongStageType_422`, `patchActivity_partial`, `deleteActivity`, `reorderActivities`, `addActivity_invalidConfig_422_SAVE` |
| AC-3 type-aware validation | `DraftValidatorTest` (JUnit, no Spring): per ActivityType happy + sad; registry returns one validator per type; unsupported type → `UNSUPPORTED_ACTIVITY_TYPE` |
| AC-4 evidence CRUD + refs | `AdminEvidenceIT.create_201`, `patch_withExpectedRowVersion`, `approveDraft_toApproved`, `archive_whenNotUsed`, `archive_whenPublishedSnapshotReferences_409`, `evidenceList_filterByEventAndStatus` |
| AC-5 transition integrity + cycles | `DraftValidatorTest.cycleDetected`, `brokenNextStageDetected`, `terminalStagePresent` |
| AC-6 duplicate IDs + schema version | `DraftValidatorTest.duplicateStageIds`, `duplicateActivityIds`, `unknownSchemaVersion_saveAllowed_publishRejected` |
| AC-7 concurrent edits (optimistic lock) | `AdminLessonStageIT.concurrentPatch_409` — two patches same stage, second with stale `expectedRowVersion` |
| AC-8 incomplete draft save | `AdminLessonStageIT.addStageWithoutInstruction_200`, `DraftValidatorTest.saveLevel_toleratesMissingConfig` |
| AC-9 publish-readiness endpoint | `AdminLessonValidateIT.ready_whenValid`, `notReady_returnsStructuredErrors`, `validateDoesNotMutate`, `validate_noLessonVersionsCreated` |
| AC-10 auth negatives | `auth_anon401_learner403` for stage/activity/evidence/validate endpoints (one IT method per controller) |
| AC-11 regression on TASK-0007/0008 | Existing `AuthRefreshIT`, `AdminEventIT`, `AdminLessonIT` still pass — must re-run mvnw verify |

## IT conventions (do not deviate)

- Extend `AbstractPostgresIT`.
- `@BeforeEach` cleanup order:
  ```java
  jdbc.update("set session_replication_role = replica");          // bypass immutable trigger
  jdbc.update("update lessons set status='DRAFT', current_version_id=null");
  jdbc.update("delete from lesson_versions");
  jdbc.update("delete from lessons");
  jdbc.update("delete from evidences");                            // NEW — must come before events
  jdbc.update("delete from assets");                               // NEW
  jdbc.update("set session_replication_role = origin");
  jdbc.update("delete from lesson_templates");
  jdbc.update("delete from historical_events");
  jdbc.update("delete from auth_refresh_tokens");
  users.deleteAll();
  ```
- Use `bearer(email, role)` helper (copy from `AdminLessonIT`).
- Use `MockMvc` + `jsonPath` assertions; do NOT introduce REST Assured.
- For `lesson_versions` writes during "published" setup, use `jdbc.update` (existing pattern).
- For optimistic-lock tests, capture `rowVersion` from GET then submit stale value.

## Unit tests (no Spring)

`DraftValidatorTest` (plain JUnit5):
- Construct `DraftValidator` with manually-instantiated validators list + mocked `EvidenceRepository` (`Mockito.mock`).
- Cases per validator (12 types) — group by `Nested` classes.
- Cases for cross-cutting checks (unique ids, transitions, cycles, evidence refs at PUBLISH level).

`StageGraphTest` (if extracted as separate class): DFS cycle detect, terminal-reachable check.

`EvidenceServiceTest` — not required (covered by IT), skip.

## Files

Create:
- `src/test/java/com/dauviet/lesson/AdminLessonStageIT.java`
- `src/test/java/com/dauviet/lesson/AdminLessonActivityIT.java`
- `src/test/java/com/dauviet/lesson/AdminLessonValidateIT.java`
- `src/test/java/com/dauviet/lesson/AdminEvidenceIT.java`
- `src/test/java/com/dauviet/lesson/application/DraftValidatorTest.java`
- `src/test/java/com/dauviet/lesson/application/validators/MultipleChoiceValidatorTest.java` (representative per-type; add others as needed)

Modify:
- `AdminLessonIT` — extend `@BeforeEach` cleanup with `delete from evidences; delete from assets;` BEFORE `delete from historical_events` (FK order); keeps existing tests green.
- `AdminEventIT` — same addition to cleanup (defensive — its tests do not create evidence, but other tests in same JVM may leave rows).

## Implementation steps
1. Update `@BeforeEach` in existing ITs to include evidence/asset cleanup.
2. `DraftValidatorTest` — pure JUnit5, per-type coverage.
3. `AdminLessonStageIT` — covers stage CRUD + reorder + auth + lock.
4. `AdminLessonActivityIT` — activity CRUD + reorder + allow-list.
5. `AdminEvidenceIT` — evidence CRUD + transitions + in-use.
6. `AdminLessonValidateIT` — readiness endpoint.
7. Run `mvnw -pl dau-viet-backend verify`; all green.

## Todo
- [ ] Update existing ITs cleanup order
- [ ] DraftValidatorTest (≥25 cases)
- [ ] AdminLessonStageIT (≥10 cases)
- [ ] AdminLessonActivityIT (≥8 cases)
- [ ] AdminEvidenceIT (≥8 cases)
- [ ] AdminLessonValidateIT (≥4 cases)
- [ ] mvnw verify green

## Success criteria
- All new tests pass; all prior tests still green.
- `mvnw -pl dau-viet-backend verify` exit 0.
- No fake data, mocks only where Spring isn't loaded.

## Risks
- Testcontainers startup time — reuse static `POSTGRES` (existing pattern).
- `session_replication_role` reset on failure — keep toggle in same `@BeforeEach` so partial cleanup is retried.
