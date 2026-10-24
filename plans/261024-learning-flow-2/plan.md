---
title: "Learning Flow 2.0 — Meaningful Learning & Automatic Assessment"
status: planned
priority: P0
risk: HIGH
created: 2026-10-24
plan_dir: plans/261024-learning-flow-2
---

# Learning Flow 2.0 — Implementation Plan (Overview)

Redesign the learning flow so every required activity has a clear purpose,
server-authoritative auto-grading (admin-authored answer keys, no AI), and
output continuity across the EVIDENCE→REASONING→HYPOTHESIS→VERIFICATION→CONCLUSION
chain. Independent of the Animation Engine / TASK-0019 HTML-WebView work — do
NOT touch `com.dauviet.animation.*`, `animation-*` files, or their uncommitted
changes.

## Deliverables (from epic brief)

1. New `CER_CHOICE` activity type — structured Claim→Evidence→Reasoning with
   answer keys. Legacy `CER` enum/semantics unchanged.
2. Graded mode for `EVIDENCE_SELECT` (`acceptedEvidenceIds`, partial scoring).
3. Graded mode for `REASONING_CONNECT` (`expectedRelations`/`acceptedRelationSets`).
4. Output continuity via `priorOutputs`; dependent-output invalidation on revise.
5. `REFLECTION` optional & ungraded.
6. Separate progress vs knowledge score; `maxAttempts` retry budget; no
   soft-lock; no hidden-answer leaks.
7. Admin Lesson Builder editors for graded activities + CER_CHOICE.
8. Flutter CER_CHOICE renderer + graded-feedback UI + purpose display.
9. Bạch Đằng 938 reference lesson (new draft/version) + second fixture.

## Coexistence approach (DECIDED — see phase-02)

**Opt-in per-activity flag: `config.graded=true`.** No `schemaVersion` bump, no
new activity enum for graded variants, no DB migration.

- Legacy activities (no `graded` flag or `graded:false`) → handlers keep the
  exact current behavior (count-only / syntax-only). Published snapshots
  unchanged — they simply lack the flag.
- New drafts set `config.graded:true` + the answer-key fields. The handler
  branches on the flag; the validator requires the key only when flagged.
- Rationale over a `schemaVersion` bump: bumping `DraftSchema.CURRENT_VERSION`
  to 2 would make every existing draft/template fail validation
  (`UNSUPPORTED_SCHEMA_VERSION`, `TEMPLATE_SCHEMA_MISMATCH`) — a breaking
  change. A per-activity flag is additive, opt-in, and keeps schemaVersion=1.
- `CER_CHOICE` is a genuinely new `ActivityType` (not a flag) because it has a
  distinct submission shape and renderer.

## Phases

| Phase | Name | Scope | Files | Status |
|---|---|---|---|---|
| 01 | Contract & schema foundation | `ActivityType.CER_CHOICE`, `DraftSchema` allowlist+hidden keys, `LEARNER_HIDDEN_KEYS` additions | `ActivityType.java`, `DraftSchema.java` | pending |
| 02 | CER_CHOICE engine + graded modes | `CerChoiceHandler`, graded branches in `EvidenceSelectHandler`/`ReasoningConnectHandler`, retry-budget generalization | `ScoredHandlers`/`SelectionHandlers`/`ReasoningHandlers`, new `CerChoiceHandler` | pending |
| 03 | Draft validation & publish readiness | `CerChoiceValidator`, graded-config validators, publish guardrails | `validators/*`, `DraftValidator` | pending |
| 04 | Output continuity + invalidation + scoring | `priorOutputs` projection surface, dependent invalidation on REVISE, knowledge-score vs progress, `maxAttempts` policy | `LearnerProjectionService`, `LearnerAttemptService`, `AttemptState`, `LessonCompletionEvaluator`, `StageTransitionResolver` | pending |
| 05 | Admin Lesson Builder | `cer-choice` editor, graded evidence/reasoning editors, activity picker, labels, preview renderer | `dau-viet-admin/src/features/lessons/builder/**`, `preview/renderers/**` | pending |
| 06 | Flutter renderers | `cer_choice_renderer.dart`, graded feedback UI, purpose/instruction display, prior-output pre-fill | `dau-viet-mobile/lib/features/learning/presentation/renderers/**`, `activity_renderer.dart`, DTOs | pending |
| 07 | Reference lesson + fixtures + tests | Bạch Đằng 938 v2 draft fixture, second lesson fixture, seed/migration, full test pass | `tasks/`, test files, optional seed | pending |

## Parallelization

- **Backend (phases 01–04):** sequential — shared files (`DraftSchema.java`,
  handler container files, `LearnerAttemptService.java`). One owner.
- **Admin (phase 05):** independent file tree — can run parallel to backend
  once the JSON contract (phase 01) is frozen.
- **Mobile (phase 06):** independent file tree — parallel once contract frozen.
- **Phase 07** depends on all prior phases.
- Shared-file flag: `dau-viet-admin/src/features/lessons/builder/draft-model.ts`
  (`ACTIVITY_TYPES`, `STAGE_ALLOWED_ACTIVITIES`) and
  `lib/features/learning/presentation/renderers/activity_renderer.dart` are
  single-owner touchpoints — do not split them across parallel agents.

## Key files to modify (verified)

Backend (`dau-viet-backend/src/main/java/com/dauviet/`):
- `lesson/draft/ActivityType.java` — add `CER_CHOICE`
- `lesson/draft/DraftSchema.java` — `STAGE_ALLOWED_ACTIVITIES[CONCLUSION]`
  += `CER_CHOICE`; `LEARNER_HIDDEN_KEYS` += new answer-key leaf names
- `lesson/draft/validators/SimpleActivityValidators.java` — extend
  `EvidenceSelectValidator`/`ReasoningConnectValidator` for graded mode
- `lesson/draft/validators/` — new `CerChoiceValidator`
- `learning/handler/` — new `CerChoiceHandler` component; graded branches in
  `EvidenceSelectHandler`, `ReasoningConnectHandler`
- `learning/handler/ActivityHandlerRegistry.java` — auto-wires new @Component
- `learning/resolver/LessonCompletionEvaluator.java` — knowledge-score clause
- `learning/resolver/StageTransitionResolver.java` — dependent invalidation
- `learning/domain/AttemptState.java` — dependent-output invalidation support
- `learning/application/LearnerAttemptService.java` — wire invalidation,
  knowledge score into result JSON, expose prior outputs for projection
- `lesson/application/LearnerProjectionService.java` — prior-output surface +
  verify recursive strip covers new keys

Admin (`dau-viet-admin/src/features/lessons/`):
- `builder/draft-model.ts`, `builder/labels.ts`, `builder/activity-picker.tsx`
- `builder/activity-editors/` — new `cer-choice-editor.tsx`, extend
  `evidence-select-editor.tsx`, `reasoning-connect-editor.tsx`, `index.tsx`
- `preview/renderers/` — new cer-choice preview renderer + dispatch

Mobile (`dau-viet-mobile/lib/features/learning/`):
- `presentation/renderers/cer_choice_renderer.dart` (new)
- `presentation/renderers/activity_renderer.dart` (dispatch)
- `presentation/renderers/evidence_select_renderer.dart`,
  `reasoning_connect_renderer.dart` (graded feedback)
- `data/attempt_dtos.dart` (prior outputs / score fields)
- `presentation/lesson_player_screen.dart` (purpose/instruction display)

## Acceptance criteria (summary — per-phase files carry the AC→check map)

- AC-1 `CER_CHOICE` submits `{claimId, evidenceIds, reasoningId}`; server grades
  against `acceptedClaims`/`acceptedEvidenceIds`/`acceptedReasoningIds`; never
  emits keys to learner DTOs.
- AC-2 Legacy `CER`, `EVIDENCE_SELECT`, `REASONING_CONNECT` unchanged on old
  published versions (no flag → legacy path).
- AC-3 Graded `EVIDENCE_SELECT`/`REASONING_CONNECT` score partial credit and
  emit per-item feedback codes, server-side only.
- AC-4 CER_CHOICE pre-fills evidence from a prior EVIDENCE_SELECT output
  without re-selection; revising upstream invalidates dependent output.
- AC-5 `REFLECTION` stage can be `required:false` and never gates completion.
- AC-6 Progress (`completedRequired/totalRequired`) reported separately from a
  knowledge score; `maxAttempts` caps retries; no soft-lock; no hidden keys.
- AC-7 Admin authors CER_CHOICE + graded activities with pickers, no raw JSON.
- AC-8 Flutter renders CER_CHOICE as 3 cards; feedback is server-driven.
- AC-9 Bạch Đằng 938 v2 + second fixture publish-valid and playable.

## Open questions for PO/BA

1. **Knowledge-score formula** — `minScore` currently = "% of required
   activities completed" (a progress metric). For graded activities, should
   knowledge score = (a) mean per-activity correctness ratio, (b) weighted
   points, or (c) count of fully-correct required activities? Plan defaults to
   (c) "graded-correct required activities / total required graded" unless BA
   specifies otherwise.
2. **Partial-completion on retry exhaustion** — when `maxAttempts` is reached
   with a wrong answer, does the activity count as completed-for-progress
   (current `MultipleChoiceHandler` behavior sets `completed=true` on
   exhaustion) or stay blocking? Plan keeps the existing "exhausted →
   completed" convention to avoid soft-lock; flag for BA sign-off.
3. **CER_CHOICE retry policy** — allow re-submit until correct, or cap via
   `maxAttempts` like MULTIPLE_CHOICE? Plan defaults to `maxAttempts`
   (default 3 for CER_CHOICE vs 1 for MCQ) — confirm.
4. **priorOutputs exposure to learner** — to pre-fill CER_CHOICE evidence, the
   client needs the prior EVIDENCE_SELECT selection. Options: (a) inject a
   learner-safe `priorOutputs` block into the projected activity config in
   `getCurrent`/`getContent` (chosen — no new endpoint), or (b) new endpoint.
   Chosen (a); confirm no leak concern (only non-hidden output fields).
5. **Bạch Đằng 938 v2 authoring path** — hand-authored fixture SQL/JSON seed
   (chosen, mirrors V17 pattern) vs. building through the admin UI. Confirm a
   seed file is acceptable for the reference lesson.

## Test gates (no Playwright)

- Backend: `./mvnw test` (unit + MockMvc; Testcontainers ITs blocked — Docker
  off). New/updated tests per phase in each phase file.
- Admin: `vitest run` + `npm run build` (typecheck).
- Mobile: `flutter test` + `flutter analyze`.
- `git diff --check` clean; no commits/pushes.
