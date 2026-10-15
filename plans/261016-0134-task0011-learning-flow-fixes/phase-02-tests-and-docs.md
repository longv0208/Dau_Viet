# Phase 02 — Tests and Docs

## Context Links

- `plan.md` requirement→check map; phase-01 for the implementation under test
- Files: `src/test/java/com/dauviet/learning/{LearnerAttemptApiIT,AttemptItFixture}.java`, `src/test/java/com/dauviet/learning/resolver/StageTransitionResolverTest.java`, `src/test/java/com/dauviet/lesson/draft/` (existing validator tests), `docs/LEARNING_ENGINE_DESIGN.md` §13

## Overview

- Priority: P1 | Status: pending | Effort: ~3h
- Cover all four defects with unit + integration tests, update §13 semantics, run `mvnw verify`.

## Key Insights

- Fixture `draftTwoStage` publishes required-only stages; add `draftWithOptional` variant (optional READ + optional MCQ alongside required ones) rather than mutating the existing fixture (existing ITs depend on `currentActivityId=r1`, `progress.totalRequired=2`).
- MCQ exhaustion IT needs `maxAttempts:2` in MC config — new config constant, don't edit `MC_CONFIG`.

## Implementation Steps

### Step 1 — Resolver unit tests (`StageTransitionResolverTest`, append)

1. `requiredIncomplete_staysOnSameActivity`: required act, not completed, outcome INCORRECT → `nextActivity().activityId()` == lastActivityId, same stageId.
2. `requiredIncomplete_partial_outcomeDrivenHopWins`: VERIFICATION-style required act with `onPartial:"hyp"`, outcome PARTIAL, not completed → `nextStage().stageId()=="hyp"`, reason REVISE (stay must not shadow the hop).
3. `requiredIncomplete_noHopTarget_stays`: `onPartial:"ghost"` → `nextActivity` same id (NOT forward advance).
4. `optionalIncomplete_stillAdvances`: optional act not completed → normal (a)-(e) walk proceeds (documents that optional never blocks).
5. `exhausted_completedRequired_advances`: required act `markCompleted` + outcome INCORRECT → next incomplete after it / next stage (exhaustion = completed → advances).

### Step 2 — SnapshotModel unit test

`SnapshotModel.parse` with two stages sharing activity id → `SnapshotCorruptException`. Put in existing `learning/snapshot` test class if present, else `SnapshotModelTest`.

### Step 3 — DraftValidator regression

In existing validator test class (`lesson/draft` tests): draft with activity id `x` in stage A and stage B → error list contains `DUPLICATE_ID` at `stages[1].activities[..].id`. If publish-path IT exists (`LessonPublishIT` or similar), add: publish → 422 `DRAFT_SCHEMA_INVALID`. Check test tree first; reuse the established harness.

### Step 4 — LearnerAttemptApiIT additions

New fixture `AttemptItFixture.draftWithOptional(evId, mcConfigWithAttempts)`:
stages: `ctx` (required; activities: `r1` READ required, `opt1` READ optional, `mcOpt` MC optional) → `ev` (required; `mc` MC required maxAttempts=2) → `[]`. `totalRequired` stays 2.

Tests:

1. `requiredFailure_retryThenExhaustion_advances`:
   - submit `r1` → cursor `ev`/`mc`.
   - submit `mc` wrong → `outcome=INCORRECT`, `activityCompleted=false`, `next.activityId=="mc"`, `GET /current` still `mc`, `progress.completedRequired==1`.
   - submit `mc` wrong again → `exhausted:true`, `activityCompleted=true`, cursor advances (null next / end), completion→complete.
2. `optionalSubmit_recordsAndKeepsCursor`:
   - at `ctx`/`r1`: submit `opt1` `{}` → 200, `activityCompleted=true`; `GET /current` still `r1`; `progress` unchanged (totalRequired=2).
   - submit `mcOpt` wrong → 200, recorded; cursor still `r1`.
   - submit `r1` → advances to `ev`/`mc`; optional `opt1` now in previous stage → submit `opt1` → 409 `ACTIVITY_NOT_AVAILABLE`.
3. `optionalFutureStage_notAccessible_409`: while cursor at `r1`, submit `mc` → 409 (already covered by `staleActivitySubmit_409`, keep as regression).
4. `multiStage_cursorProgressConsistent`: after every submit above assert `GET /attempts/{id}` `progress` + `currentActivityId` + `completion` coherence (completedRequired monotonic, cursor matches `/current`).
5. Extend `noHiddenKeyLeak_inAnyResponse`: assert the optional-submit response body too.
6. `duplicateActivityId_publish422`: admin PUT/publish draft with same activity id across two stages → 422 + `DRAFT_SCHEMA_INVALID` (+ `DUPLICATE_ID` in details if the envelope exposes per-field errors — match existing validator IT style).

### Step 5 — Docs

`docs/LEARNING_ENGINE_DESIGN.md` §13:

- Amend resolver bullet: prepend "(0) submitted required activity chưa `completed` → REVISE hop nếu `onPartial/onContradicted` khớp target, ngược lại cursor GIỮ NGUYÊN (retry)" and note steps (a)-(e) only run after completed/optional submission.
- Add row: optional activities — cursor chỉ dừng ở required; submit lên optional trong current stage được chấp nhận, ghi attempt/output, không đổi cursor, không tính progress/completion.
- Add row: activity id phải unique toàn snapshot (publish-time `DUPLICATE_ID`; runtime `SnapshotCorruptException`).

`docs/API_SPEC.md`: if submit endpoint documents path semantics, add one line that optional activities in the current stage are submittable. Skip if no such section (don't invent structure).

### Step 6 — Verify

`cd dau-viet-backend && ./mvnw verify` — full suite green.

## Todo List

- [ ] 5 resolver unit tests
- [ ] SnapshotModel dup-id test
- [ ] Validator cross-stage DUPLICATE_ID test (+ publish 422 IT if harness exists)
- [ ] `draftWithOptional` fixture + MC config with maxAttempts
- [ ] 4–5 new ITs incl. progress/cursor assertions + hidden-key extension
- [ ] §13 doc update (+ API_SPEC line if section exists)
- [ ] `mvnw verify` exit 0

## Success Criteria

- Every plan.md requirement→check row has a named, passing test.
- All TASK-0008..0011 existing ITs green unmodified.
- `git diff --check` clean; no new files outside tests.

## Risk Assessment

- Fixture drift: keep `draftTwoStage` byte-identical; new draft is additive.
- Flaky ordering: `completedActivityIds` is a LinkedHashSet — assert membership, not order, where JSON arrays are compared.
- Docker-required ITs: same `@SpringBootTest`/Postgres harness already used; no new infra.

## Next Steps

- On green: report to lead for `code-reviewer` pass; TASK-0012 (rewards/idempotency/`lesson_results`) unaffected.
- Open question for user/PO: publish-time guardrail for required activities that can never complete (unbounded retry with no revise path) — currently author responsibility.
