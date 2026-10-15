# Phase 01 — Engine and Validator Fixes

## Context Links

- `plan.md` D1–D3 decisions
- `docs/LEARNING_ENGINE_DESIGN.md` §13 (semantics to preserve)
- Files: `learning/resolver/StageTransitionResolver.java`, `learning/application/LearnerAttemptService.java`, `learning/snapshot/SnapshotModel.java`, `lesson/draft/DraftValidator.java`

## Overview

- Priority: P1 | Status: pending | Effort: ~3h
- Three surgical fixes: stay-on-incomplete-required, optional-activity submission guard, global activity-id uniqueness. No new files, no API/state/schema changes.

## Key Insights

- `nextIncompleteRequired(model.activitiesOf(stageId), state, lastActivityId)` skips `lastActivityId` itself — root cause of soft-lock.
- Handlers returning `completed=false` on required activities: `MultipleChoiceHandler` (INCORRECT, attemptNo < maxAttempts), `VerificationHandler` (PARTIAL/CONTRADICTED), `EvidenceSelectHandler` (IN_PROGRESS below minRequired), `ExploreMapHandler` (IN_PROGRESS below minMarkers). Optional submits must still record `activity_attempts` rows and `state.outputs`.
- Revise-hop (`onPartial`/`onContradicted`) must be evaluated BEFORE the stay-fallback, else VERIFICATION remediation dies.

## Requirements

- Functional: (1) required + `completed=false` → cursor stays (or REVISE hop); (2) optional in current stage submittable; (3) cross-stage duplicate activity id → `DUPLICATE_ID`; (4) SnapshotModel rejects duplicate ids on parse.
- Non-functional: no DTO/endpoint/state changes; pessimistic-lock submit path unchanged.

## Implementation Steps

### Step 1 — `StageTransitionResolver.resolve()` stay-rule (D1)

File: `learning/resolver/StageTransitionResolver.java`

At top of `resolve()`, after the null-stage guard:

1. Resolve `JsonNode last = model.activityById(lastActivityId)`.
2. If `last != null && last.path("required").asBoolean(false) && !state.isCompleted(lastActivityId)`:
   - a. Attempt the existing outcome-driven hop (extract current step (b) logic into `reviseTarget(model, activity, lastOutcome)` helper returning `NextStage` or null). If non-null → `Transition.of(nextStage)`.
   - b. Else → `Transition.of(toNextActivity(model, stageId, lastActivityId))` — cursor stays.
3. Otherwise fall through to existing steps (a)-(d) unchanged. Keep step ordering (a)→(b) for completed activities: same-stage incomplete-after wins over hop (preserves current tests).

Update the class Javadoc bullet list to reflect the new step (0).

### Step 2 — `LearnerAttemptService.submit()` optional-submit guard (D2)

File: `learning/application/LearnerAttemptService.java`, cursor check ~line 187.

Replace the equality-only guard:

```
boolean onCursor = activityId != null && activityId.equals(state.currentActivityId());
JsonNode activity = model.activityById(activityId);
boolean optionalInStage = !onCursor && activity != null
        && !activity.path("required").asBoolean(false)
        && state.currentStageId() != null
        && state.currentStageId().equals(model.stageIdOf(activityId));
if (!onCursor && !optionalInStage) throw new ActivityNotAvailableException(...);
if (activity == null) throw new SnapshotCorruptException(...);
```

After evaluation: if `optionalInStage` (not on cursor) → skip `transitionResolver.resolve` entirely; return `SubmitActivityResponse` with `next` = NextActivity pointing at the unchanged cursor (stageId + currentActivityId + type + projected config), or `next=null` if cursor is null. Cursor, `currentStageId` untouched. Still `recordOutput`, `markCompleted` when `result.completed()`, and persist the `activity_attempts` row.

Progress (`progressOf`) and completion evaluator already count required only — no change.

### Step 3 — Global activity-id uniqueness (D3)

File: `lesson/draft/DraftValidator.java`

- In `validate()`: allocate `Set<String> activityIds = new HashSet<>()` next to `stageIds`; pass it into `validateStages(...)` and on to `validateActivities(...)`.
- In `validateActivities`: delete the per-stage `Set<String> actIds = new HashSet<>()` (~line 198); use the shared set — `!activityIds.add(actId)` → `FieldError(apath + ".id", "DUPLICATE_ID", "duplicate activity id '" + actId + "'")`. Message unchanged otherwise.
- `validateStages` signature gains the set param (private method — safe).

File: `learning/snapshot/SnapshotModel.java` — in ctor loop (~line 49):

```
if (activityById.put(aid, act) != null) {
    throw new SnapshotCorruptException("duplicate activity id '" + aid + "' in snapshot");
}
stageOfActivity.put(aid, sid);
```

(Use the `put` return value; also covers same-stage dup which validator already catches — belt.)

## Related Code Files

Modify: `learning/resolver/StageTransitionResolver.java`, `learning/application/LearnerAttemptService.java`, `learning/snapshot/SnapshotModel.java`, `lesson/draft/DraftValidator.java`.
Create/Delete: none.

## Todo List

- [ ] Resolver: stay-rule + extracted `reviseTarget` helper + Javadoc
- [ ] Service: optional-in-stage guard + conditional transition + `next` payload
- [ ] DraftValidator: shared `activityIds` set threaded through validate→validateStages→validateActivities
- [ ] SnapshotModel: duplicate-id `SnapshotCorruptException`
- [ ] Compile: `mvnw -q compile` (backend module)

## Success Criteria

- `mvnw compile` clean; existing unit tests (`StageTransitionResolverTest`, handler tests) still pass unmodified except where a test asserted the old broken advance (audit: `linear_sameStageNextRequired` uses `lastActivityId="opt"` optional — unaffected; `optionalSubmit_doesNotGateAdvance` submits required `rq` already completed — unaffected).
- No API contract, state_json shape, or DB change.

## Risk Assessment

- Stay-rule could infinite-loop a lesson where a required activity can NEVER complete (e.g. no maxAttempts and deterministic fail). Semantics per §13 say VERIFICATION is retried after revise; MCQ exhausts via maxAttempts. Accept: lesson designers own terminability; publish guardrail for unbounded required retry is out of scope (note as open question).
- `SubmitActivityResponse.next` for optional submits: ensure `activityType`/`learnerConfig` fields populated consistently with existing builder block — reuse the same construction code path; extract a small private `toNextDto(...)` if needed to avoid duplication (DRY).

## Security Considerations

- Optional-submit path must run the same ownership/status/pinned-snapshot checks — it does (guard placement after `loadOwned`-equivalent checks in `submit()`).
- Hidden keys: optional activity results go through the same `result(...)`/`projectActivity` sanitization.

## Next Steps

Phase 02 adds regression/unit/IT coverage and the §13 doc update.
