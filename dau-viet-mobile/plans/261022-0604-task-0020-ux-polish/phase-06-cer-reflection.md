# Phase 06 — CER + REFLECTION polish

## Overview

- Priority: P1
- Status: pending
- Goal: clearer section hierarchy, readable fields, live counters,
  keyboard-safe scroll, focus traversal, preserved drafts on network
  error.

## Files

Modify:
- `lib/features/learning/presentation/renderers/cer_renderer.dart`
- `lib/features/learning/presentation/renderers/reflection_renderer.dart`
- `lib/features/learning/presentation/lesson_player_screen.dart` —
  ONLY to add `padding: EdgeInsets.only(bottom:
  MediaQuery.of(context).viewInsets.bottom)` on the inner
  `SingleChildScrollView` so keyboard doesn't cover fields. Do NOT
  touch `_submit`, `_confirmExit`, `PopScope`, `_needsFreshKey`,
  `myProgressProvider` invalidate logic.

## Contracts preserved

- CER: `{'claim': String, 'evidenceIds': List<String>, 'reasoning':
  String}`. Min length 20 for claim/reasoning — client-side hint only,
  server authoritative.
- REFLECTION: `{'text': String}` when no options, `{'optionId': String}`
  when `config.options` present. Existing behavior prefers options —
  keep.
- `onInputChanged` must fire with true whenever ANY field has content
  (preserves dirty-input Back dialog + draft on network error).

## CER changes

1. Section structure — already three `SectionLabel`s; upgrade to
   numbered steps: `'BƯỚC 1 — LUẬN ĐIỂM (CLAIM)'`, `'BƯỚC 2 — BẰNG
   CHỨNG'`, `'BƯỚC 3 — LẬP LUẬN'`. Add helper `_stepLabel(int n, String
   text)` returning `SectionLabel`.
2. Claim field:
   - `TextField` → keep, add `focusNode: _claimFocus` +
     `textInputAction: TextInputAction.next`, `onSubmitted: (_) =>
     _reasonFocus.requestFocus()`.
   - Counter `'${len}/20 ký tự tối thiểu'` already exists — make the
     check green via `DauVietColors.natureGreen` (existing token —
     replace hardcoded `Color(0xFF4C7C44)`).
3. Evidence chips:
   - Use `evidenceSourceText(e)` for a subtitle inside the chip — keep
     `FilterChip` (single line limit). Alternative: switch to the
     `_EvidenceTile` look (no — keep chips, just add source via
     `avatar: Icon(Icons.menu_book, size:14)`).
   - Chip `selected` should not clear text — already correct; verify
     `_evidenceIds` survives across evidence-chip taps + text edits (it
     does; both use `setState` on same state class).
4. Reasoning field: `maxLines: 6`, counter same as claim.
5. Disabled states during submit: `enabled: !widget.submitting` already
   on TextField; chips use `onSelected: submitting ? null : ...` —
   already correct.
6. Draft preservation: text controllers already hold state; on
   `ApiException` player keeps widget alive — verified. No extra work.
7. New `Padding` for keyboard: handled by parent scroll view change
   above — no renderer change needed.

## REFLECTION changes

1. Prompt — keep `ActivityCard` with `bodyMedium`.
2. Options branch (RadioListTile):
   - Wrap each `RadioListTile` in a `ParchmentCard` with selected
     border `cinnabarRed` — gives visual feedback like MCQ tiles.
   - Replace `dense` with `controlAffinity:
     ListTileControlAffinity.leading`, `contentPadding:
     EdgeInsets.symmetric(horizontal:12, vertical:4)`.
   - Haptic on selection.
3. Text branch:
   - `maxLength: 4000` — already set; add `maxLengthEnforcement:
     MaxLengthEnforcement.enforced`.
   - Live counter below field: `'${len}/4000'` in `bodySmall`. Remove
     Material's built-in counter via `buildCounter` returning
     `SizedBox.shrink()` to avoid duplicate counters.
   - `textInputAction: TextInputAction.newline` (multiline).
   - `FocusNode` + `onTapOutside: (_) => FocusScope.of(context).unfocus()`.
   - Keyboard padding handled by player ScrollView.
4. `onInputChanged` fires whenever `_textCtrl.text` non-empty OR
   `_optionId != null` — already correct; verify on `_textCtrl.text`
   clearing also fires false.
5. Submit enable logic unchanged.

## Todo

- [ ] Player ScrollView bottom padding for viewInsets.
- [ ] CER: numbered section labels, focus traversal, natureGreen for
      counter-valid state.
- [ ] Reflection: card-wrapped radio options, custom counter, focus
      unfocus on outside tap.
- [ ] Verify chips/fields disable while submitting AND keep text.

## Risks

- `FocusScope.of(context).unfocus()` inside `onTapOutside` — available
  Flutter 3.10+; safe.
- Adding viewInsets padding to player may shift the SubmitBar into a
  visible area — that's the intended effect.
