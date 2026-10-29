# TASK-0028 Handoff — Issue #35 4-phase learning chain

## Independent review — addressed
Reviewer verdict REQUEST_CHANGES; all findings resolved in this pass:
- **BLOCKER**: V7 seed mutated → reverted; new `V52__update_history_template_4phase_preset.sql` carries the preset update (avoids Flyway checksum break).
- **MAJOR** template-form conclusion preset had `CER_CHOICE` with empty `claims/reasoningOptions/acceptedCombos` (save-rejectable) → emptied activities; author adds CER later.
- **MAJOR** `validateVerification` required `expectedHypothesis` (backend tolerates null) → dropped the mandatory check, kept `checkMaxAttempts`.
- **MINOR** `GRADED_3_LEVEL_TYPES` included `CER` (free-text, no PARTIAL/EXHAUSTED) and `MULTIPLE_CHOICE` (no PARTIAL) → split: graded set now {EVIDENCE_SELECT, MATCHING, REASONING_CONNECT, DRAG_ORDER, CER_CHOICE}; MCQ gets `EXHAUSTED`-only rule via `MCQ_TYPES`.
- **MINOR** HypothesisRenderer prefill re-added collected evidence on every rebuild → `_prefilled` flag gates to one-shot.
- **MINOR** `InlineGradingHint` missed `partsCorrect` (CER_CHOICE) → reads `partsCorrect` fallback `Đúng k/3 phần`; `CerChoiceRenderer` now mounts hint.
- **MINOR** `lastEvaluation` persisted after completion → completion branch rewrites `lastEvaluation: () => res.evaluation` (fresh terminal eval replaces stale retry one).

## Status
`implementing` → all review findings addressed, ready to commit. All module gates green (backend 532 unit + 391 IT; admin 290 vitest; mobile 282+3 pre-existing fails).

## Delivered

### Backend (`dau-viet-backend`)
- `DraftSchema.STAGE_ALLOWED_ACTIVITIES` — `DISCOVERY` allows `EXPLORE_MAP/VIEW_IMAGE/MULTIPLE_CHOICE/READ`; `EVIDENCE` allows `EVIDENCE_SELECT/MULTIPLE_CHOICE/VIEW_IMAGE/READ`; `HYPOTHESIS` allows `HYPOTHESIS_CHOICE/MULTIPLE_CHOICE/READ`. READ universal.
- `ScoredHandlers.java`:
  - `MatchingHandler` — `correctCount` counted pair-by-pair (was `submitted.size()`), emits `matchedCount`/`correctPositions`/`totalItems`/`attemptCount`/`exhausted`; outcomes `COMPLETED`(full) / `PARTIAL`(correctCount>0 && !exhausted) / `INCORRECT`; `maxAttempts` default 3 → `exhausted:true` + completed-for-progress, feedback key `"EXHAUSTED"`.
  - `DragOrderHandler` — canonical = `expectedOrder` else `acceptedSequences[0]`; positional `correctPositions`; `PARTIAL` when `correctPositions*2 >= canonical.size()`; same budget/`EXHAUSTED` semantics.
- Validators (`SimpleActivityValidators`, `MultipleChoiceValidator`): `requireBoundedInt(config,"maxAttempts",path,1,20)` on MatchingValidator, DragOrderValidator, MultipleChoiceValidator, ReasoningConnectValidator (inside `graded` gate — backend handler only enforces when graded).
- `HiddenKeyLeakIT` — 8-stage draft walks READ→EVIDENCE_SELECT(graded)+MC→MATCHING→HYPOTHESIS_CHOICE→VERIFICATION→DRAG_ORDER→CER_CHOICE; no hidden key surfaces.
- `V51__upgrade_lessons_4phase_chain.sql` — upserts 16 group evidences (`[Hiện vật]/[Địa hình]/[Nhân vật]/[Cổ thư]` labeled, `HISTORICAL_TEXT` type), upgrades 4 lessons' `draft_json` to the 7-stage chain (`context→discovery(EVIDENCE/EVIDENCE_SELECT)→hypothesis→verify→reconstruct→conclusion`), publishes `lesson_versions` version_no=2 with embedded `evidence[]`+`assets[]` (V30 CTE pattern), updates `current_version_id`. `$$`/`$draft$` nesting fixed: outer `DO $$` + inner `$draft$` tag, plus space after tag to avoid Flyway placeholder `${` parse.
- `V7__seed_default_lesson_template.sql` — preset expanded to 6-stage chain (context→discovery→hypothesis→verification→reconstruction→conclusion).

### Admin (`dau-viet-admin`)
- `draft-model.ts` allow-list synced to new stage map.
- `draft-local-validator.ts` — `GRADED_3_LEVEL_TYPES` (excludes VERIFICATION), `checkMaxAttempts(1..20)`, `idOf()` narrowing helper; new validators `validateMatching`, `validateMultipleChoice`, `validateHypothesisChoice` (≥2), `validateVerification` (`expectedHypothesis` required), `validateReasoningConnect`; `validateEvidenceSelect` errors when `graded!==true`; `validateFeedback` requires `PARTIAL`+`EXHAUSTED` for graded types, `SUPPORTED`+`CONTRADICTED` for VERIFICATION.
- Editors: `MaxAttemptsField` in `shared-fields.tsx`, inserted into drag-order/matching/multiple-choice; `evidence-select-editor` forces `graded:true` (toggle display-only, `persistGraded()` wraps every config onChange).
- `interaction-renderers.tsx` — `deriveColumns()` fallback for MATCHING raw `pairs[]` (fixes version-detail render).
- `template-form.tsx` `DEFAULT_PRESET` — 7-stage chain with CER_CHOICE conclusion.
- `scripts/e2e-backend-stub.mjs` — preset updated to 6-stage chain.
- `src/test/fixtures.ts` — MC + DRAG_ORDER feedback gains `PARTIAL`+`EXHAUSTED` (fixes builder-page tests).

### Mobile (`dau-viet-mobile`)
- `attempt_dtos.dart` — `EvaluationDto`: `correctPositions`/`totalItems`/`attemptCount`/`exhausted`/`matchedCount`/`partsCorrect`/`verificationVerdict`; `ActivityRefDto.maxAttempts`.
- `lesson_player_screen.dart` — `_PlayerState.lastEvaluation` (retry-in-place); `_feedbackFor` wires `outcome` and appends progress detail (`Đúng k/n · Còn x/y`); celebration title `switch(fb.outcome)` → SUPPORTED/CONTRADICTED/PARTIAL variants.
- `activity_renderer.dart` — `lastEvaluation` field, forwarded to all 9 renderer call sites.
- All 9 renderers gained `final EvaluationDto? lastEvaluation;` + `this.lastEvaluation` ctor param.
- `hypothesis_renderer.dart` — `_priorEvidenceIds()` reads `config.priorOutputs[priorEvidenceSource|evidenceSource].selectedEvidenceIds`; evidence chips = `visibleEvidenceIds ∪ collected`, prefilled with collected.
- `renderer_base.dart` — `InlineGradingHint` widget (gold banner `Đúng k/n · còn x/y`, hidden on COMPLETED/SUPPORTED/no data).
- `drag_order/matching/evidence_select` renderers — `InlineGradingHint` inserted above `SubmitBar` with `maxAttempts: widget.activity.maxAttempts`.
- Tests — `learning_dtos_test.dart` +7 tests for new DTO fields; `lesson_player_test.dart` tap fix (`ensureVisible` before tap — MascotSpeechBubble pushed button offscreen).

### Docs
- `LEARNING_ENGINE_DESIGN.md §13.1` — 4-phase chain, shared output contract, PARTIAL thresholds.
- `API_SPEC.md` — Issue #35 grading output bullet.

## Test results
- Backend: `mvn test` — **532/532 pass**; `mvn test -Dtest='*IT'` — **391/391 pass** (V51 migration runs clean on Testcontainers Postgres 16).
- Admin: `npx vitest run` — **290/290 pass**; `npm run typecheck` — clean on all edited files (pre-existing errors only in `island-builder/*`, `map-locations/*`, `lib/dto/map-location.ts`); `npm run lint` — 1 pre-existing warning (`cer-choice-editor.tsx` unused `catalogIds`).
- Mobile: `flutter analyze` — clean on all edited files (pre-existing unused-import warnings on drag_order/multiple_choice renderers); `flutter test test/learning/` — **282 pass, 3 pre-existing failures** confirmed on base commit (bisected via `git stash`): `lesson_player_energy_test.dart` ENERGY_DEPLETED-409 + FIX-5 (provider sync), unrelated to Issue #35.

## Risks / notes
- `functions.edit` boundary-echo bug: several files needed repair passes; all now parse. Re-read region before further edits on touched files.
- ReasoningConnectValidator's `maxAttempts` bound sits inside `graded:true` gate (handler only enforces when graded) — intentional; flag if product wants it always bounded.
- `correctPositions`/`totalItems`/`attemptCount`/`exhausted` are the shared output contract — do not rename without updating both admin FeedbackPanel docs and mobile `EvaluationDto` getters.
- V51 nested-dollar-quote: outer `DO $$` wraps `$draft$`-tagged JSON payloads; do not revert to `$$…$$` inside the DO block.
- Pre-existing test debt flagged, not fixed: `lesson_player_energy_test.dart` ×2, admin typecheck in island-builder/map-locations.

## Next action
Independent `code-reviewer` pass (high-risk gate) → update `acEvidence`/`reviewRefs` → flip `status: "done"` → commit + push within user authorization.
