# Phase 02 — MULTIPLE_CHOICE polish

## Overview

- Priority: P1
- Status: pending
- Goal: clearer selection feedback, single vs multi clarity, proper touch
  targets, disabled state during submit, keep selected answer visible
  alongside server feedback.

## File

Modify: `lib/features/learning/presentation/renderers/multiple_choice_renderer.dart`

## Contract preserved

- Submits `{'selectedOptionIds': List<String>}` — do not change.
- `config.multiSelect` (bool) drives single vs multi.
- `config.options` — list of `{id, label|text}`.
- Client does NOT know correctness — no green/red reveal after submit.

## Current issues to fix

1. No visible difference between "selected" and "hover" — feedback is
   purely a thin border color change.
2. Touch target ≈ 44 px already ok but InkWell has no `minSize` —
   increase vertical padding to 14.
3. While `submitting`, tiles are disabled but **not visually dimmed** —
   user gets no signal.
4. No hint whether multi-select is allowed.
5. After submit → `awaitingContinue`, selected answer must stay visible
   (already does because widget is keyed on `activity.id`; keep it).

## Changes

1. Add `SectionLabel` above options:
   - `multi == true` → `'CHỌN TẤT CẢ ĐÁP ÁN ĐÚNG'`
   - else → `'CHỌN MỘT ĐÁP ÁN'`
   - If `config['instruction']` exists show it via `ActivityCard` already
     handled by parent (player renders `cur.activity!.instruction`) — do
     not duplicate.
2. `_OptionTile` updates:
   - Wrap the inner `Container` in `AnimatedContainer(duration: 150ms,
     curve: Curves.easeOut)` for color/border transitions. Guard with
     `MediaQuery.of(context).disableAnimations ? Duration.zero : ...`.
   - Add `Semantics(button: true, selected: selected, enabled: enabled,
     label: label)` at the outermost node so screen readers announce
     state.
   - Dim when `!enabled` — `opacity: 0.55` on the row, no shadow.
   - Increase padding: `EdgeInsets.symmetric(horizontal: 14, vertical: 14)`.
   - Border: keep `selected` = `cinnabarRed` 1.6 w. Unselected tile gets
     `outlineVariant` 1 w. Add `surfaceTint`: when `selected`, background
     = `DauVietColors.cinnabarRed.withValues(alpha: 0.10)`; hover on
     unselected (mouse) — rely on InkWell's default splash — no extra
     hover needed.
   - Icon: keep `check_box`/`radio_button_checked`; size 22.
   - Add `trailing` micro-copy when `multi && selected`: `Icons.check`
     on the right side — optional; keep simple.
3. `onTap` → `HapticFeedback.selectionClick()` before `_tap(id)` —
   import `package:flutter/services.dart`.
4. `onInputChanged` — already calls with `_selected.isNotEmpty`; keep.
5. Submit button: enabled only when `_selected.isNotEmpty` AND NOT
   `widget.submitting`. `SubmitBar` already handles `enabled`+`submitting`
   — no change needed.

## Keep

- `_multi` getter, `_tap` logic, the `for (final opt in options)` loop.
- `question` display via `ActivityCard` at top.

## Todo

- [ ] Add SectionLabel with single/multi hint.
- [ ] Convert `_OptionTile` inner container to `AnimatedContainer`.
- [ ] Add `Semantics` + dim-when-disabled.
- [ ] Increase padding, add `HapticFeedback.selectionClick()`.
- [ ] Verify `submitting` still disables; test `awaitingContinue` keeps
      selection visible.

## Risks

- AnimatedContainer + InkWell combination: keep `borderRadius` identical
  on both to avoid clipped splash.
