# Phase 04 — Output Continuity, Invalidation & Scoring

## Context Links
- plan: `plans/261024-learning-flow-2/plan.md`
- `learning/domain/AttemptState.java` (outputs map, completedActivityIds)
- `learning/application/LearnerAttemptService.java` (doSubmit, projection)
- `learning/resolver/StageTransitionResolver.java` (REVISE hops)
- `learning/resolver/LessonCompletionEvaluator.java`
- `lesson/application/LearnerProjectionService.java`
- `learning/api/dto/*` (CurrentActivityResponse, LessonResultResponse)

## Overview
- Priority: P0
- Status: pending
- Depends on: phases 01–03
- Four concerns: (a) surface prior outputs to the learner so CER_CHOICE can
  pre-fill evidence; (b) invalidate dependent outputs when an upstream activity
  is revised; (c) separate progress from a knowledge score; (d) REFLECTION
  optional/ungraded + confirm no soft-lock.

## Key Insights
- `priorOutputs` already exists server-side (`AttemptState.outputs`); handlers
  read it via `AttemptContext`. The gap is **learner visibility**: the mobile
  CER_CHOICE renderer needs the prior `selectedEvidenceIds`. Cheap path: when
  projecting the CURRENT activity, merge a learner-safe `priorOutputs` block
  into the activity's projected config — no new endpoint.
- Dependent invalidation: today, revising an upstream activity (e.g. a REVISE
  hop from VERIFICATION→HYPOTHESIS) leaves the old downstream output in
  `state.outputs`. When `HypothesisChoiceHandler` is re-submitted, the old
  VERIFICATION output is stale but still marked completed. MVP scope (per
  brief): implement bounded invalidation — when an activity is re-submitted,
  remove `completedActivityIds` + `outputs` entries for activities that were
  completed *after* it within the same attempt AND declare `dependsOn` (or are
  downstream in the same stage chain). Simplest robust rule: on any new
  submission for activity X, drop completions/outputs of activities in the
  same stage that come after X in the stage's `activities` array, plus
  VERIFICATION-stage activities that consumed X. **Decide in implementation;
  document the rule.**
- Score: `LessonResultResponse`/`resultJson` already carries `score` =
  completedRequired/totalRequired — a *progress* metric. Add a separate
  `knowledgeScore` in resultJson = mean of graded-activity correctness (each
  graded activity contributes `output.score` 0..1 or `correct` 1/0; non-graded
  required activities contribute 1.0 if completed else 0.0 — simplest formula;
  flag formula to BA per open question #1).
- No-soft-lock: `StageTransitionResolver` step (0) already keeps the cursor on
  a failed required activity; graded handlers must set `completed=true` on
  exhaustion (same as MCQ) to preserve this.

## Requirements

### A. Prior-output surface (LearnerProjectionService + LearnerAttemptService)
- `LearnerAttemptService.getCurrent` + `getContent` (content endpoint):
  after `projection.projectActivity(activity)`, if the activity type is
  `CER_CHOICE` (or any type — generic), merge `config.priorOutputs` =
  `{<activityId>: <stripped output>}` for each output already in
  `AttemptState.outputs`. Strip via the same hidden-key rule (outputs never
  contain hidden keys by construction since `result()` strips, but run the
  strip anyway for defense-in-depth).
- Alternative simpler shape: only inject the outputs of the activity named in
  `config.priorEvidenceSource`. **Chosen: inject all current outputs under
  `config.priorOutputs`** — generic, data-driven, no per-type branch.
- DTO change: none — `config` is already a free-form JsonNode in
  `CurrentActivityResponse.Activity`/`LearnerLessonContent`.

### B. Dependent invalidation
- In `LearnerAttemptService.doSubmit`, after `state.recordOutput` /
  `markCompleted` for the submitted activity X:
  - compute dependent ids = activities completed after X (track completion
    order — AttemptState uses `LinkedHashSet`, so order is available) that are
    in a later position of the same stage's `activities` array, or in a stage
    listed in X's stage's `nextStageIds` subtree (bounded: only direct
    next-stage descendants, depth 1, to keep MVP small).
  - DECISION (MVP): invalidate = remove from `completedActivityIds` and
    `outputs` any activity Y where Y ≠ X AND Y was completed AND
    `snapshotReachable(X.stage → Y.stage)` through `nextStageIds` (direct edge
    or same-stage-later-position). Log invalidations.
  - This forces re-verification: e.g. re-submitting HYPOTHESIS_CHOICE clears a
    completed VERIFICATION → cursor step-(a)/(d) returns the learner there.

### C. Progress vs knowledge score
- `resultJsonOf(...)`: add `knowledgeScore` (0–100, 2dp) =
  `100 * Σ(perActivityScore) / totalRequired` where perActivityScore =
  `output.score` if present else `correct?1:0` else (completed ? 1 : 0) —
  over *required* activities only.
- Also add `knowledgeScore` to `AttemptProgressResponse` (or a new field
  alongside `progress`) so in-flight UI can show both meters. Keep the
  existing `score` field untouched for backward compat (documented as
  progress percent).
- `LessonCompletionEvaluator`: optionally allow a new completion clause
  `minKnowledgeScore` — **YAGNI check: brief says "separate progress vs
  knowledge score"; adding the *field* is required, a new completion clause is
  optional. Implement field only; skip new clause unless BA asks.**

### D. REFLECTION optional & ungraded
- Already structurally supported: `required:false` stage + optional activity
  never gates (publish guardrail `REQUIRED_IN_OPTIONAL_STAGE` enforces the
  pattern). `ReflectionPromptHandler` (in `AcknowledgmentHandlers`) marks
  completed on any submission — verify it does not block completion when
  required:false. No code change expected; add a regression test.
- REFLECTION_PROMPT remains free-text but optional — brief compliant.

### E. Retry budget generalization
- `maxAttempts` honored by CER_CHOICE + both graded branches (phase 02). Ensure
  `attemptCount` is written into every graded output (needed by
  `priorAttempts`).

## Related Code Files
Modify:
- `learning/application/LearnerAttemptService.java`
- `learning/domain/AttemptState.java` (add `removeOutput`/`uncomplete` helpers)
- `learning/resolver/StageTransitionResolver.java` (if cursor rules need it —
  likely none; verify)
- `lesson/application/LearnerProjectionService.java` (priorOutputs merge may
  live here as `projectActivity(activity, outputs)` overload)
- `learning/api/dto/AttemptProgressResponse.java` (add knowledgeScore)
- `learning/domain/LessonResult.java`/resultJsonOf (score fields)
Tests:
- `LearnerAttemptServiceTest`/`LearnerAttemptControllerTest` (MockMvc) —
  invalidation, priorOutputs surface, dual score
- `StageTransitionResolverTest` — revise-loop regression

## Implementation Steps
1. `AttemptState`: add `removeCompleted(id)` + `removeOutput(id)` +
   `outputsInsertionOrder` helpers.
2. `LearnerProjectionService.projectActivity(JsonNode activity,
   Map<String,JsonNode> priorOutputs)`: overload; inject
   `config.priorOutputs` with deep-stripped copies.
3. `LearnerAttemptService.getCurrent`/`getContent`: pass `state.outputs()`.
4. `doSubmit`: after recording, compute + apply dependent invalidation
   (bounded scope above); persist.
5. `resultJsonOf` + `AttemptProgressResponse`: add `knowledgeScore`.
6. Regression test: REFLECTION optional does not gate completion.
7. `./mvnw -q compile && ./mvnw -q test -Dtest='Learner*,*Resolver*,*State*'`.

## Todo
- [ ] AttemptState mutation helpers
- [ ] projection priorOutputs surface
- [ ] dependent invalidation in doSubmit
- [ ] knowledgeScore in result + progress DTO
- [ ] REFLECTION optional regression test
- [ ] tests green

## Success Criteria
- MockMvc: submit EVIDENCE_SELECT → getCurrent(CER_CHOICE) shows
  `config.priorOutputs.<evidenceAct>.selectedEvidenceIds`.
- Re-submit upstream activity → dependent completed activity un-completed;
  resolver returns learner to it.
- `resultJson` contains both `score` (progress) and `knowledgeScore`.
- Optional REFLECTION stage skip → lesson can still complete.
- No endpoint added; all flows remain idempotent (existing idempotency tests
  green).

## Risk Assessment
- Invalidation rule over-deleting → cap scope to direct next-stage descendants
  + same-stage-later; unit-test the boundary.
- `priorOutputs` leak: outputs contain no hidden keys by construction; still
  re-strip on projection (belt & suspenders).
- Cursor regressions: `StageTransitionResolver` untouched unless tests show a
  gap; soft-lock guard from TASK-0011 must stay green.

## Security Considerations
- priorOutputs injection must pass through `LEARNER_HIDDEN_KEYS` strip — a
  graded output must never reveal `expected*`/`accepted*`.
