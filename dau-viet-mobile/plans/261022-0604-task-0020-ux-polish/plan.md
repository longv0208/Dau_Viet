---
title: "TASK-0020 — Learning UX polish + historical recap"
description: "Polish all learning renderers (READ/VIEW_IMAGE/MCQ/MATCHING/DRAG_ORDER/EVIDENCE_SELECT/CER/REFLECTION), fix MATCHING right-tile enabled precedence bug, add LessonResultScreen recap built only from pinned snapshot."
status: pending
priority: P1
effort: 8h
branch: main
tags: [learning, ux, flutter, polish, recap]
created: 2026-10-22
---

# TASK-0020 — Learning UX polish + historical recap

Polish learner-facing renderers and the result screen without breaking the
TASK-0019 flow (Submit → Feedback → Continue, resume cursor, pinned versions,
idempotency, dirty-input back guard, mock/real split, answer contracts).

## Guiding constraints

- No new packages. Use `InteractiveViewer` (built-in) for pinch-zoom and
  Flutter's in-memory `Image.memory` cache — `cached_network_image` and
  `photo_view` are NOT in `pubspec.yaml`.
- Keep every renderer under 200 lines; extract sub-widgets into existing
  files or small private widgets in the same file.
- Reuse tokens: `DauVietColors.*`, `DauVietTypography.*`,
  `ParchmentCard`, `DongSonButton`, `SubmitBar`, `ActivityCard`,
  `SectionLabel`, `LearningAssetImage`.
- All animations must respect `MediaQuery.of(context).disableAnimations`
  and stay cheap (`AnimatedContainer`, `AnimatedOpacity`, `AnimatedSize`).
- Haptics only via `HapticFeedback.selectionClick()` / `lightImpact()` on
  tap-select actions — never on long-press or drag.
- Server is authoritative. Never compute correctness, never expose
  `expectedOrder`, `requiredEvidenceIds`, `answerKey`.

## Phases

| # | Phase | Files touched | Status |
|---|-------|---------------|--------|
| 01 | READ + VIEW_IMAGE polish | `renderers/read_renderer.dart`, `renderers/view_image_renderer.dart`, `renderers/learning_asset_image.dart` | pending |
| 02 | MULTIPLE_CHOICE polish | `renderers/multiple_choice_renderer.dart` | pending |
| 03 | MATCHING polish + precedence fix | `renderers/matching_renderer.dart` | pending |
| 04 | DRAG_ORDER polish | `renderers/drag_order_renderer.dart` | pending |
| 05 | EVIDENCE_SELECT polish | `renderers/evidence_select_renderer.dart` | pending |
| 06 | CER + REFLECTION polish | `renderers/cer_renderer.dart`, `renderers/reflection_renderer.dart`, `lesson_player_screen.dart` (scroll padding only) | pending |
| 07 | Historical recap on result | `lesson_result_screen.dart` (extend), maybe new small `presentation/recap_section.dart` | pending |
| 08 | Polish sweep + tests | all above + `test/learning/*` focused widget tests | pending |

## Bug found during research (must fix in Phase 03)

`matching_renderer.dart` line ~104 — right-tile `enabled` is parsed as
`(!widget.submitting && _activeLeft != null) || usedRight.contains(...)`.
Because `||` binds looser than `&&`, a paired right tile stays enabled
**while submitting** — lets learner unmatch mid-submit. Fix with parens
and explicit unmatch path.

## Contracts to preserve (do not touch)

- `answer.selectedOptionIds` (MCQ), `answer.pairs=[{leftId,rightId}]`
  (MATCHING), `answer.orderedIds` (DRAG_ORDER), `answer.selectedEvidenceIds`
  (EVIDENCE_SELECT), `{claim, evidenceIds, reasoning}` (CER),
  `{text|optionId}` (REFLECTION), `{revise:true}` (VERIFICATION),
  `{hypothesisId, evidenceIds}` (HYPOTHESIS), `{relations:[{from,to,relation}]}`
  (REASONING_CONNECT), `{markerId}` (EXPLORE_MAP).
- `lesson_player_screen.dart`: `_submit` early-return guard incl.
  `completionReady`, `PopScope canPop = !_hasUnsentInput`,
  `_confirmExit`/`_exitNow` + `_exitDialogOpen`, `_needsFreshKey` lifecycle,
  `ref.invalidate(myProgressProvider)` on complete/exit, `submitting ||
  awaitingContinue || completionReady` fan-out to renderer.
- No new fields on DTOs; recap uses existing snapshot data only.

## Verification

- `dart format .`
- `flutter analyze` — must stay clean (currently 0 issues).
- `flutter test` — all existing 129 tests pass; add focused widget tests
  for MATCHING precedence fix and recap fallback (Phase 08).

## Out of scope

- New backend endpoints, new DTO fields, new packages, theme overhaul,
  changes to VERIFICATION / HYPOTHESIS_CHOICE / REASONING_CONNECT /
  EXPLORE_MAP / UnsupportedRenderer beyond what is needed to keep shared
  helpers compiling.
