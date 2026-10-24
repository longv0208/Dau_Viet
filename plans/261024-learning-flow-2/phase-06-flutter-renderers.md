# Phase 06 — Flutter Renderers (Learner UI)

## Context Links
- plan: `plans/261024-learning-flow-2/plan.md`
- `dau-viet-mobile/lib/features/learning/presentation/renderers/activity_renderer.dart` (dispatch)
- `renderers/cer_renderer.dart`, `evidence_select_renderer.dart`,
  `reasoning_connect_renderer.dart`, `hypothesis_renderer.dart` (patterns)
- `renderers/renderer_base.dart` (SubmitBar, ActivityCard, SectionLabel)
- `data/attempt_dtos.dart` (EvaluationDto.output, ActivityRefDto.feedback)
- `presentation/lesson_player_screen.dart`, `stage-guidance.dart`

## Overview
- Priority: P1
- Status: pending
- Depends on: phase 01 (contract); ideally phase 04 (priorOutputs surface) for
  pre-fill, but the renderer degrades gracefully without it.
- New `cer_choice_renderer.dart` (3-section card UI, no textarea), graded
  feedback rendering for EVIDENCE_SELECT/REASONING_CONNECT, and
  purpose/instruction display. All feedback is server-driven via
  `EvaluationDto`/`feedbackCode`.

## Key Insights
- `ActivityRefDto.feedback` already resolves `feedbackCode → text`
  (`feedbackText(code)`) — graded flows reuse this; new codes
  (PARTIAL/EXHAUSTED) need no DTO change, only authored `feedback` keys.
- `EvaluationDto.output` is already exposed — renderer can read
  `output.partsCorrect`, `output.score`, `output.correctCount`,
  `output.exhausted` for result display after submit.
- priorOutputs continuity: `getCurrent` response activity config will carry
  `config.priorOutputs` (phase 04). CER_CHOICE pre-fills its evidence section
  from `priorOutputs[config.priorEvidenceSource].selectedEvidenceIds`; absent
  → empty selection, learner picks manually.
- No client-side correctness: renderer never compares to accepted keys (they
  are stripped server-side anyway); submit → display `evaluation` verdict.

## Requirements

### `cer_choice_renderer.dart` (new)
- Three `SectionLabel`-headed groups:
  1. **Luận điểm (Claim)** — radio list over `config.claims[{id,text}]`.
  2. **Bằng chứng (Evidence)** — checkbox cards over `config.evidenceOptions`
     (resolve metadata via `content.evidenceById(id)` like
     `EvidenceSelectRenderer`), pre-checked from
     `config.priorOutputs[priorEvidenceSource].selectedEvidenceIds`; "đã chọn
     trước" hint chip on pre-filled items; learner may add/remove.
  3. **Suy luận (Reasoning)** — radio list over `config.reasoningOptions`.
- Submit `{claimId, evidenceIds, reasoningId}` via `onSubmit`.
- Enable SubmitBar only when all three parts non-empty.
- After submit, parent shows `evaluation.feedbackCode → feedbackText` +
  `output.partsCorrect/3` — reuse the player's existing feedback surface
  (check `lesson_player_screen.dart` for where `SubmitResultDto` is rendered;
  add per-part icons if output carries them — keep to counts for MVP).
- No forced textarea anywhere; no local answer checking.

### Graded feedback in existing renderers
- `evidence_select_renderer.dart`: if `config.graded == true`, after submit
  display `output.correctCount`/`falseCount`/`score` (server-provided) in the
  result area; do not mark which ids were correct (would leak the key —
  counts only).
- `reasoning_connect_renderer.dart`: same — show `output.matchedRelations` /
  `incorrectCount` + feedbackText; never which tuple was wrong (key leak) —
  **BA check: per-connection feedback is in the brief; showing "3/5 connections
  correct" is safe; per-tuple marks would reveal the key. Decide: counts only
  for MVP unless BA accepts marked-tuple display post-submit.**

### Purpose / instruction display
- `activity.instruction` already flows; ensure `lesson_player_screen.dart`
  shows it prominently (check `stage-guidance.dart`); add stage-purpose line
  from `stage.title` if absent — verify during implementation, minimal change.

### Dispatch
- `activity_renderer.dart`: `case 'CER_CHOICE': return CerChoiceRenderer(...)`.

## Related Code Files
Create:
- `renderers/cer_choice_renderer.dart`
Modify:
- `renderers/activity_renderer.dart`
- `renderers/evidence_select_renderer.dart`
- `renderers/reasoning_connect_renderer.dart`
- `data/attempt_dtos.dart` only if new DTO fields needed (output already Map)
- possibly `lesson_player_screen.dart` (instruction display polish)
Tests:
- `test/features/learning/...` widget tests mirroring existing renderer tests

## Implementation Steps
1. Read `cer_renderer.dart` + `hypothesis_renderer.dart` for selection-card
   patterns; build `cer_choice_renderer.dart` reusing `renderer_base` widgets.
2. Register in `activity_renderer.dart` dispatch.
3. Add graded result display in evidence/reasoning renderers.
4. Prior-output pre-fill wiring (guard for missing priorOutputs).
5. `flutter analyze` + `flutter test`.

## Todo
- [ ] cer_choice_renderer.dart + dispatch
- [ ] graded feedback UI: evidence_select + reasoning_connect
- [ ] priorOutputs pre-fill
- [ ] instruction/purpose display verified
- [ ] flutter analyze + test green

## Success Criteria
- CER_CHOICE renders 3 sections; submit disabled until all chosen; sends exact
  contract answer shape.
- Pre-filled evidence reflects prior EVIDENCE_SELECT output when present.
- Feedback text + counts come from `evaluation` only (no client grading).
- `flutter analyze` clean, existing + new widget tests pass.

## Risk Assessment
- priorOutputs missing (backend phase 04 not landed) → renderer must treat as
  optional (null-safe) — no hard dependency.
- Leaking which evidence was correct → display counts only; per-item correct
  marks are NOT shown in MVP.

## Security Considerations
- Renderer never sees `accepted*`/`expected*` keys (server strips); assert in
  a widget test that config lacks them by fixture shape.
