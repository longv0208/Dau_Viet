# Phase 07 — Reference Lesson, Second Fixture & Full Verification

## Context Links
- plan: `plans/261024-learning-flow-2/plan.md`
- `dau-viet-backend/src/main/resources/db/migration/` (V17 pattern: idempotent
  ON CONFLICT seed)
- `docs/LEARNING_ENGINE_DESIGN.md`, `docs/PROJECT_OVERVIEW.md`
- `tasks/` (task.json convention)

## Overview
- Priority: P1
- Status: pending
- Depends on: phases 01–06
- Author the new Bạch Đằng 938 flow as a NEW lesson draft/version (never touch
  the old published snapshot) covering the full chain with graded activities
  and a CER_CHOICE conclusion; plus a second smaller lesson proving the engine
  is data-driven (no event-specific code). Final cross-module verification.

## Key Insights
- The reference lesson must already exist as an event (`bach-dang-938` slug is
  seeded — V17 resolved scene↔event via slug). The new lesson is a second
  `lessons` row + draft — or a NEW VERSION of the existing Bạch Đằng lesson via
  the normal draft→publish path (preferred: keeps one lesson, immutable old
  version, attempts pinned to old version unaffected).
- Authoring path (DECIDED, open Q#5): seed the draft via a migration/fixture
  file in the V17 idempotent style (`INSERT ... ON CONFLICT`), then publish
  through the service — OR provide a `tasks/TASK-XXXX/brief.md` + a
  `scripts/`/test fixture that drives `LessonDraftService` + `LessonPublishService`
  in a `@SpringBootTest`-free unit path. **Choose: JSON fixture file under
  `dau-viet-backend/src/test/resources/lessons/` consumed by a publish-flow
  test + an optional V20 seed migration for dev data.** Final decision at
  implementation; both must produce identical draft JSON.
- Second fixture: minimal 3-stage lesson (EVIDENCE→CONCLUSION with CER_CHOICE)
  on a different event (e.g. `hai-ba-trung-40` or `ly-thai-to-1010` — both have
  animation content already) proving no eventId branches.

## Requirements

### Reference lesson: Bạch Đằng 938 v2
Stage chain (per brief):
1. CONTEXT — READ (+ optional animationSceneVersionId pin — reuse existing
   published scene if desired; NOT required by this epic).
2. EVIDENCE — graded `EVIDENCE_SELECT` (acceptedEvidenceIds = the tide/
   stake/ambush evidence rows; ensure those evidence records exist for the
   event — create in the same seed if absent).
3. REASONING — graded `REASONING_CONNECT` (nodes = quân Nam Hán / thủy triều /
   bãi cọc / phục kích; expectedRelations = tide-hides-stakes → ambush).
4. HYPOTHESIS — `HYPOTHESIS_CHOICE` (≥2 hypotheses).
5. RECONSTRUCTION — `DRAG_ORDER` (sequence: đóng cọc → dụ địch → triều lên →
   phục kích → triều xuống → tan vỡ).
6. VERIFICATION — `VERIFICATION` with `onPartial`/`onContradicted` REVISE hops
   back to HYPOTHESIS stage (bounded loop — existing resolver).
7. CONCLUSION — required `CER_CHOICE` (`priorEvidenceSource` = the EVIDENCE
   stage's select activity; accepted keys authored).
8. REFLECTION — `required:false` stage with optional `REFLECTION_PROMPT`.

All ids slug-style `ID_PATTERN`; no eventId in configs; `feedback` filled for
every outcome used; `completion` = `requireAllRequiredStages:true` (or
requiredStageIds list — pick one and document).

### Second fixture lesson
- New lesson on a different event, minimal: EVIDENCE(graded)→CONCLUSION
  (CER_CHOICE) → optional REFLECTION. Proves engine reuse without event
  branches.

### Verification matrix (per-phase AC → checks)

| AC | Check | Gate |
|---|---|---|
| AC-1 CER_CHOICE grading | `CerChoiceHandlerTest` (correct/partial/incorrect/exhausted/invalid-id) | `mvnw test` |
| AC-2 legacy unchanged | existing `SelectionHandlersTest`, `ReasoningHandlersTest`, `CerHandler` tests unchanged-green | `mvnw test` |
| AC-3 graded modes | new tests in `SelectionHandlersTest`/`ReasoningHandlersTest` | `mvnw test` |
| AC-4 continuity+invalidation | `LearnerAttemptServiceTest`/MockMvc: submit EVIDENCE_SELECT→CER_CHOICE sees priorOutputs; upstream re-submit invalidates downstream | `mvnw test` |
| AC-5 REFLECTION optional | completion test: skip optional stage → verdict complete | `mvnw test` |
| AC-6 progress vs knowledge + no leak | resultJson contains both scores; projection strip test asserts no `accepted*`/`expected*` keys at any depth | `mvnw test` |
| AC-7 admin authoring | `cer-choice-editor.test.tsx`, `draft-model.test.ts` round-trip | `vitest` + `npm run build` |
| AC-8 flutter renderer | `cer_choice_renderer_test.dart`, dispatch test | `flutter test` + analyze |
| AC-9 fixtures publish-valid | `DraftValidatorTest` PUBLISH-level on both fixture JSONs → zero errors | `mvnw test` |

### Docs
- Update `docs/LEARNING_ENGINE_DESIGN.md` (new activity type, graded flag,
  continuity rule, dual score) and `docs/API_SPEC.md` if response shapes gained
  fields (`knowledgeScore`, `config.priorOutputs`). Delegate to docs-manager.
- `docs/PROGRESS.md` regeneration only if task.json tracking is used — check
  whether a TASK-XXXX entry is created for this epic; if so, brief + task.json.

## Related Code Files
Create:
- `dau-viet-backend/src/test/resources/lessons/bach-dang-938-v2.draft.json`
- `dau-viet-backend/src/test/resources/lessons/second-fixture.draft.json`
- optional `db/migration/V20__learning_flow_2_seed.sql` (dev data; evidence +
  lesson draft — only if PO wants it seeded)
- `test/.../learning/handler/CerChoiceHandlerTest.java`
- `test/.../lesson/draft/CerChoiceValidatorTest.java`
- `test/.../learning/application/LearnerAttemptServiceTest.java` (extend or new)
- admin: `cer-choice-editor.test.tsx`; mobile: `cer_choice_renderer_test.dart`
Modify:
- `docs/LEARNING_ENGINE_DESIGN.md`, `docs/API_SPEC.md`
- possibly `tasks/TASK-XXXX/` for tracking

## Implementation Steps
1. Write both fixture draft JSONs; validate PUBLISH-level via
   `DraftValidatorTest`-style harness → iterate to zero errors.
2. Ensure referenced evidence/assets exist (reuse event evidence; create seed
   rows in fixture setup if missing).
3. Decide + implement authoring path (fixture test vs V20 seed).
4. Run the whole verification matrix above.
5. Docs updates via docs-manager.
6. `git diff --check`; confirm no animation-engine files touched
   (`git status` scope review).

## Todo
- [ ] bach-dang-938 v2 draft JSON publish-valid
- [ ] second fixture draft JSON publish-valid
- [ ] authoring path decided + implemented
- [ ] full backend test pass (`./mvnw test` — note Docker/Testcontainers
      blocked, document)
- [ ] admin vitest + build green
- [ ] flutter test + analyze green
- [ ] docs updated
- [ ] no animation/TASK-0019 files touched

## Success Criteria
- Both lessons validate at PUBLISH with zero errors.
- All phase test gates green (backend unit+MVC, admin vitest+build, flutter).
- Old published Bạch Đằng version untouched; in-flight attempts unaffected.
- `git diff --check` clean; diff contains no `animation/*` paths.

## Risk Assessment
- Fixture evidence rows may not exist for the event → create them in the same
  seed/fixture setup; verify with `checkEvidenceRefs` at PUBLISH.
- V20 seed could conflict with existing dev data → use fixed UUIDs +
  `ON CONFLICT DO NOTHING` (V17 pattern).
- Docker-off blocks IT verification → document as blocked, not skipped;
  unit+MVC coverage compensates.

## Security Considerations
- Fixtures contain answer keys — they are draft data (server-side), never
  shipped to learner endpoints; projection tests assert stripping.
