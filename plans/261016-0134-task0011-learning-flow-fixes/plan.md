---
title: "TASK-0011 Final Learning Flow Correctness Fixes"
description: "Fix required-retry soft-lock, add optional-activity navigation, enforce global activity-id uniqueness, extend IT coverage — no API surface changes"
status: pending
priority: P1
effort: 6h
branch: main
tags: [learning-engine, stage-transitions, draft-validation, correctness]
created: 2026-10-16
---

# TASK-0011 Follow-up — Learning Flow Correctness Fixes

## Context Links

- Prior plan: `plans/261016-0055-task0011-learning-engine/` (shipped, commit a463327)
- Semantics: `docs/LEARNING_ENGINE_DESIGN.md` §13; API: `docs/API_SPEC.md`
- Code: `learning/application/LearnerAttemptService.java`, `learning/resolver/StageTransitionResolver.java`, `learning/resolver/LessonCompletionEvaluator.java`, `learning/snapshot/SnapshotModel.java`, `learning/domain/AttemptState.java`, `learning/handler/ScoredHandlers.java`, `lesson/draft/DraftValidator.java`
- Tests: `src/test/java/com/dauviet/learning/{LearnerAttemptApiIT,AttemptItFixture}.java`, `learning/resolver/StageTransitionResolverTest.java`

## Verified Defects (from code review)

1. **Required-retry soft-lock** (`LearnerAttemptService.submit` + resolver step (a)): when a handler returns `completed=false` (MCQ INCORRECT under `maxAttempts`, VERIFICATION PARTIAL/CONTRADICTED, EVIDENCE_SELECT/EXPLORE_MAP below threshold), `resolve()` searches for the next incomplete required activity *after* `lastActivityId`, so the cursor advances. The cursor-equality guard in `submit()` (line 187) then rejects every retry with `ACTIVITY_NOT_AVAILABLE` — the required activity can never complete → attempt soft-locked. Exhaustion (`exhausted:true`) currently marks completed, so only sub-budget failures lock.
2. **Optional activities unreachable**: `firstRequiredActivityId` + `nextIncompleteRequired` bypass optional entirely; `submit()` 409s them. No way to experience optional content.
3. **Cross-stage activity-id collision**: `DraftValidator.validateActivities` uses a per-stage `actIds` set; `SnapshotModel.activityById` silently overwrites duplicates across stages.
4. **IT gaps**: no coverage for failed-required retry, optional navigation, multi-stage+optional mixes, duplicate ids.

## Design Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Incomplete required keeps cursor: in `resolve()`, check the just-submitted activity first — if `required && !completed` → honor authored revise-hop (`onPartial`/`onContradicted` → REVISE NextStage) if a target maps, else return `Transition.of(NextActivity(sameStage, sameActivity))` (stay). Steps (a)-(e) run only when the activity completed or is optional. | Minimal change; preserves revise-hop semantics in §13; retry until `completed` (incl. exhausted). No state/schema change. |
| D2 | Optional navigation = *accessible-but-not-cursor*: cursor still rests on first incomplete **required** activity only (`firstRequiredActivityId`, `nextIncompleteRequired` unchanged). Relax `submit()`'s cursor-equality guard: also accept any `required==false` activity belonging to `state.currentStageId`. Optional submits evaluate/record normally but never move the cursor and never count toward `progress`/`completion` (required-only, unchanged). | Learners "experience" optional work by submitting it; "skip" by simply proceeding (cursor already points past it). Zero new endpoints, zero state fields, backward compatible — every existing test still passes. |
| D3 | Global activity-id uniqueness: lift `actIds` from per-stage to one `Set<String>` allocated in `validate()` and threaded into `validateStages`/`validateActivities` → `DUPLICATE_ID` across stages. `SnapshotModel` ctor: `activityById`/`stageOfActivity` put → `SnapshotCorruptException` when id already present (defense for hand-edited snapshots). Composite identity rejected (YAGNI: single flat id space already assumed everywhere). | Cheapest correct fix; author-facing 422, runtime 500 only on corrupt data. |
| D4 | `Next` DTO unchanged; when staying on the same activity, `next` = NextActivity pointing at the same id (client just re-renders current). | No contract change. |

## Phase Index

| # | File | Status | Summary |
|---|---|---|---|
| 01 | `phase-01-engine-and-validator-fixes.md` | pending | Resolver stay-rule, submit() optional-submit guard, DraftValidator global id set, SnapshotModel dup guard |
| 02 | `phase-02-tests-and-docs.md` | pending | Unit + IT coverage for all four defects; LEARNING_ENGINE_DESIGN §13 update; `mvnw verify` green |

## Requirement → Check Map

| Brief req | Phase | Acceptance check |
|---|---|---|
| 1. Incomplete required cannot advance; retry exhaustion explicit | 01,02 | Unit: PARTIAL/INCORRECT-under-budget → cursor stays; exhausted → advances; onPartial hop still fires. IT: MCQ maxAttempts=2 wrong→stay→wrong→exhausted→advance. |
| 2. Optional experience-or-skip | 01,02 | IT: submit on optional in current stage → 200 + attempt row; cursor unchanged; skipping costs nothing; optional outside current stage → 409. |
| 3. Global activity-id uniqueness | 01,02 | IT: publish draft, same activity id in two stages → 422 `DRAFT_SCHEMA_INVALID` w/ `DUPLICATE_ID` detail. Unit: `SnapshotModel.parse` dup → `SnapshotCorruptException`. |
| 4. IT coverage incl. cursor/progress consistency | 02 | Each new IT asserts `GET /attempts/{id}` progress + `/current` cursor after every submission. |
| 5. Preserve pinned version, auth, hidden keys, contracts | 02 | Existing ITs untouched and green; `noHiddenKeyLeak` extended to optional-submit response. |
| 6. `mvnw verify` green | 02 | Exit 0. |

## Risk Assessment

- **Existing-attempt state drift**: state_json shape unchanged; in-flight attempts resume fine (cursor semantics only tighten where they were broken).
- **Revise-hop regression**: keep ordering — incomplete-required stay check must still allow the REVISE hop; encode as unit test first.
- **Submit-guard relaxation widens attack surface**: optional-submit still enforces ownership, IN_PROGRESS status, activity existence in pinned snapshot, and same-stage restriction. Answer keys still stripped via `projection.projectActivity`/`AbstractActivityHandler` output whitelist.
- **Validator signature change**: `validateActivities` is private — no external callers.

## Docs Impact

minor — LEARNING_ENGINE_DESIGN §13 gains two bullet rows (stay-rule + optional-navigation contract); API_SPEC unchanged (same endpoints, same envelope; submit path-param semantics documented if a note exists).
