# Phase 05 — Tests: Unit + Integration

## Context Links

- `docs/AGENT_WORKFLOW.md` verification policy
- `dau-viet-backend/src/test/java/com/dauviet/AbstractPostgresIT.java` — Testcontainers base
- `dau-viet-backend/src/test/java/com/dauviet/lesson/AdminLessonPublishIT.java` — fixture pattern (jdbc inserts, jwt.createAccessToken, PUBLISHED event)
- `dau-viet-backend/src/test/java/com/dauviet/lesson/LearnerLessonApiIT.java`
- `dau-viet-backend/src/test/java/com/dauviet/lesson/application/LearnerProjectionServiceTest.java` — unit test pattern

## Overview

| Priority | Status | Effort |
|---|---|---|
| P0 | pending | 3h |

Tests prove: every handler produces correct learner-safe results, resolvers handle linear + non-linear + revision paths, the API enforces ownership + state transitions + no answer-key leaks, and concurrent submits are serialized safely.

## Requirements

### Unit tests (`src/test/java/com/dauviet/learning/`)

| File | Coverage |
|---|---|
| `handler/AcknowledgmentHandlersTest.java` | READ/VIEW_IMAGE/REFLECTION_PROMPT valid+invalid payload |
| `handler/ExploreMapHandlerTest.java` | valid marker, unknown marker, minMarkers accumulation across submits |
| `handler/SelectionHandlersTest.java` | EVIDENCE_SELECT min-count + unknown-evidence rejection; HYPOTHESIS_CHOICE hypothesis validation + records output for VERIFICATION |
| `handler/ScoredHandlersTest.java` | MCQ correct/incorrect/exhausted; MATCHING pair-set equality; DRAG_ORDER exact match + acceptedSequences |
| `handler/ReasoningHandlersTest.java` | REASONING_CONNECT valid/invalid relation; VERIFICATION SUPPORTED/PARTIAL/CONTRADICTED; CER completion semantics |
| `handler/HandlerSafetyTest.java` | For every handler, craft a submission whose `answer` text contains hidden-key strings (e.g. `"correctOptionIds"`), assert emitted `output`/`feedback` JSON contains no leaf name in `DraftSchema.LEARNER_HIDDEN_KEYS` |
| `handler/ActivityHandlerRegistryTest.java` | All 12 types resolvable; duplicate supports() fails; unknown type → `UnsupportedActivityTypeException` |
| `snapshot/SnapshotModelTest.java` | parses `AdminLessonPublishIT`-style fixture; resolves stage/activity by id; throws on missing `stages` array |
| `resolver/StageTransitionResolverTest.java` | linear walk; non-linear branching; revision via onPartial/onContradicted; optional activity does not gate; cycle-safe malformed snapshot |
| `resolver/LessonCompletionEvaluatorTest.java` | each completion clause independently + combined + absent completion default |
| `domain/AttemptStateTest.java` | round-trip `state_json` serialization |

### Integration tests (`src/test/java/com/dauviet/learning/`)

| File | Coverage |
|---|---|
| `LearnerAttemptApiIT.java` | full happy-path: publish lesson via API → start attempt → get current → submit → next → complete; ownership (403 for other user); 404 unpublished lesson; 409 stale activity submit; anonymous 401 |
| `LearnerAttemptConcurrencyIT.java` | two threads submit same activity simultaneously on same attempt — assert exactly one `attempt_no=1` row + second request gets structured error or serializes to `attempt_no=2`; uses `ExecutorService` + `CountDownLatch` per `AdminLessonPublishIT` pattern |
| `PinnedVersionIT.java` | start attempt on v1 → republish v2 (via `POST /admin/lessons/{id}/publish`) → submit on attempt → assert evaluation uses v1 snapshot (e.g., answer correct under v1 keys but wrong under v2 keys still marked correct) |
| `HiddenKeyLeakIT.java` | for every endpoint in the surface, traverse response JSON recursively asserting zero leaf-name match against `DraftSchema.LEARNER_HIDDEN_KEYS` |

### Fixture strategy

Reuse the `AdminLessonPublishIT` pattern:

- `users.save(new User(...))` + `jwt.createAccessToken(user)` for learner token.
- `jdbc.update("insert into historical_events ... status='PUBLISHED'")`, `lesson_templates`, `evidences`, `assets` rows.
- `POST /api/v1/admin/lessons` to create lesson, `PUT /api/v1/admin/lessons/{id}/draft` (or via `AdminLessonCreateRequest.draftJson` on create), then `POST /api/v1/admin/lessons/{id}/publish`. Reuse `publishableDraft` helper for a publishable two-stage draft.
- Helper `startAttempt(lessonId)` returns `attemptId`.

## Related Code Files

**Create**

- `dau-viet-backend/src/test/java/com/dauviet/learning/handler/AcknowledgmentHandlersTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/handler/ExploreMapHandlerTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/handler/SelectionHandlersTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/handler/ScoredHandlersTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/handler/ReasoningHandlersTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/handler/HandlerSafetyTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/handler/ActivityHandlerRegistryTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/snapshot/SnapshotModelTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/resolver/StageTransitionResolverTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/resolver/LessonCompletionEvaluatorTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/domain/AttemptStateTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/LearnerAttemptApiIT.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/LearnerAttemptConcurrencyIT.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/PinnedVersionIT.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/HiddenKeyLeakIT.java`

## Implementation Steps

1. Write unit tests for each handler in parallel with implementation (or immediately after).
2. Write resolver + state + snapshot-model unit tests.
3. Write `LearnerAttemptApiIT` happy-path first, then negative paths.
4. Write `LearnerAttemptConcurrencyIT` and `PinnedVersionIT`.
5. Write `HiddenKeyLeakIT` — a single IT that walks the response of every endpoint.

## Todo List

- [ ] All handler unit tests green
- [ ] Resolver + completion + snapshot + state unit tests green
- [ ] `LearnerAttemptApiIT` covering happy + ownership + unpublished + stale-activity + anonymous
- [ ] `LearnerAttemptConcurrencyIT` serialized submit verified
- [ ] `PinnedVersionIT` proves pinned version isolation
- [ ] `HiddenKeyLeakIT` traverses every emitted JSON recursively
- [ ] Existing TASK-0008/0009/0010 ITs still green (`mvnw verify` on backend module)

## Success Criteria

- `mvnw -pl dau-viet-backend verify` exit 0.
- Each AC maps to at least one test (AC→test mapping recorded in task.json `acEvidence` by implementer).
- No skipped/`@Disabled` tests.

## Risk Assessment

- **Testcontainers availability** — ITs require Docker; ensure dev env has Docker running before `mvnw verify`.
- **Concurrency test flakiness** — use `CountDownLatch` + bounded timeout per `AdminLessonPublishIT.publish_concurrent_singleWinner_noVersionNoCollision`.
- **Fixture duplication** — extract a shared `LessonFixtureSupport` helper if three+ ITs repeat the same draft-construction code (KISS: only extract when actually duplicated).

## Security Considerations

- `HiddenKeyLeakIT` is the primary defense against leaking answer keys — must exercise at least one of each `ActivityType` through the API, not only MCQ.

## Next Steps

- Phase 06: docs + verification + task.json update.
