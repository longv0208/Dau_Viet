# Phase 03 — Stage Transition Resolver and Lesson Completion Evaluator

## Context Links

- `docs/LEARNING_ENGINE_DESIGN.md` §7 (attempt state machine), §8 (submit pseudocode), §9 (guardrails incl. cycle/terminal checks already enforced at publish)
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/DraftValidator.java` — `validateStageGraph` already enforces acyclic + terminal reachable at publish; runtime only needs the walk
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/DraftSchema.java` — `COMPLETION_KEYS` = `requireAllRequiredStages|requiredStageIds|minScore`
- Phase 01 `SnapshotModel` + `AttemptState` + contracts `StageProgress`, `NextActivity`, `NextStage`, `LessonCompletion`

## Overview

| Priority | Status | Effort |
|---|---|---|
| P0 | pending | 3h |

Two pure, stateless resolvers consumed by the runtime service in phase 04. `StageTransitionResolver` decides the next `NextActivity`/`NextStage` after a successful submission; `LessonCompletionEvaluator` decides whether the attempt is complete under the snapshot `completion` config.

## Requirements

### `StageTransitionResolver` (`com.dauviet.learning.resolver`)

Input: `SnapshotModel`, `AttemptState` (post-submit), `String currentActivityId`.
Output: `NextActivity` OR `NextStage` OR `null` (lesson finished by progression, not completion config).

Algorithm:

1. Locate current stage `S` and current activity `A` inside `S`.
2. Within `S`, find the first `required=true` activity **after** `A` (in array order) whose id ∉ `AttemptState.completedActivityIds` → return `NextActivity(S.id, that.id)`.
3. If none, mark `S` "required-complete" (all `required=true` activities done; non-required activities are optional and do not gate).
4. Determine next stage:
   - If `A.outcome` was `PARTIAL` or `CONTRADICTED` AND activity has `onPartial`/`onContradicted` field → return `NextStage(stageId=<mapped>, reason=REVISE)`.
   - Else iterate `S.nextStageIds` in order; pick the first stage `T` whose required activities are not all complete → `NextStage(T.id, reason=FORWARD)` and compute `T`'s first required activity → return `NextActivity(T.id, firstRequired.id)` (if `T` has no required activities, recurse on `T.nextStageIds` — bounded by DAG).
   - If all `nextStageIds` targets have their required activities already complete (possible in non-linear convergent paths), pick the first incomplete required stage in `stages` array order reachable from `S` — preserves "no skipping" while handling non-linear DAGs.
   - If none → return `null` (no further activity; completion evaluator decides).
5. Cycle safety: `nextStageIds` is acyclic per publish validation; resolver still carries a `visited` set during recursion to guard against hand-edited snapshots.

### `LessonCompletionEvaluator` (`com.dauviet.learning.resolver`)

Input: `SnapshotModel`, `AttemptState`.
Output: `LessonCompletion`.

Reads `completion` object inside snapshot:

- `requireAllRequiredStages` (default `false`): if `true`, every `stages[i].required=true` stage must have all its `required=true` activities completed.
- `requiredStageIds` (default `[]`): every listed stage id must have all its `required=true` activities completed.
- `minScore` (default absent): if present, compute `score = (completed required activities) / (total required activities)` * 100; `score >= minScore` required.
- AND-combination: all specified clauses must hold; if `completion` absent → lesson complete when no `required` activities remain un-completed anywhere in the snapshot.

Output `reason` field documents which clause decided (`ALL_REQUIRED_STAGES`, `REQUIRED_STAGE_IDS`, `MIN_SCORE`, `DEFAULT_ALL_REQUIRED`, `NOT_COMPLETE`).

## Related Code Files

**Create**

- `dau-viet-backend/src/main/java/com/dauviet/learning/resolver/StageTransitionResolver.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/resolver/LessonCompletionEvaluator.java`

**Modify**

- `dau-viet-backend/src/main/java/com/dauviet/learning/snapshot/SnapshotModel.java` — add `stageById(id)`, `activityById(stageId, activityId)`, `requiredActivities(stageId)`, `completionNode()`, `entryStageId()` helpers if not already present in phase 01.

## Implementation Steps

1. Extend `SnapshotModel` with the lookup helpers listed above (read-only).
2. Implement `StageTransitionResolver.resolveNext(SnapshotModel, AttemptState, lastActivityId, lastOutcome)` per algorithm; document non-linear pick order in javadoc.
3. Implement `LessonCompletionEvaluator.evaluate(SnapshotModel, AttemptState)` per rules above.
4. Unit tests:
   - Linear A→B→C walk.
   - Non-linear A→{B,C}→D: B finished → C picked; both finished → D.
   - Revision loop: VERIFICATION `PARTIAL` with `onPartial:"stage-hyp"` → `NextStage(stage-hyp, REVISE)`.
   - Cycle-guarded: malformed snapshot with cycle returns `SNAPSHOT_INVALID_FOR_ACTIVITY` instead of infinite loop.
   - Required gating: optional activity submitted does not advance stage; required does.
   - Completion evaluator: each clause + combined AND.

## Todo List

- [ ] `SnapshotModel` helpers
- [ ] `StageTransitionResolver` + unit tests covering linear, non-linear, revision, cycle-safe, required-gating paths
- [ ] `LessonCompletionEvaluator` + unit tests covering each clause + combined + absent-completion default
- [ ] Verify resolver returns `NextStage(reason=REVISE)` only when activity has the matching `on*` field

## Success Criteria

- Resolver test matrix covers all branches (linear, branching, convergent, revision, terminal).
- Completion evaluator returns `NOT_COMPLETE` when a required stage is missing one required activity.
- No stack overflow / infinite loop on a hand-crafted cyclic snapshot — returns structured error.

## Risk Assessment

- **Non-linear semantics under-specified** — chosen policy (first `nextStageIds` entry with incomplete required activities, then first incomplete required stage in array order) is deterministic and documented; alternative policies (e.g., learner picks) deferred to product decision.
- **Score definition** — `minScore` defined as fraction of completed required activities; BA may instead want rubric-weighted score. Documented choice; flag for review.
- **`onPartial`/`onContradicted` reference stage ids** — publish validator does not yet verify they point to existing stages; runtime resolver tolerates missing targets by treating as `FORWARD` (documented limitation; tighten at publish in follow-up task).

## Security Considerations

- Resolvers emit only ids/types/reasons — no config internals — so no leak path.

## Next Steps

- Phase 04: wire service + controller.
