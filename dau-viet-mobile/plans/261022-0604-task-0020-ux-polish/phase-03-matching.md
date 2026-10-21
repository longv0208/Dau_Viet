# Phase 03 — MATCHING polish + precedence bug fix

## Overview

- Priority: P1 (bug) + P2 (polish)
- Status: pending
- Goal: fix `enabled` precedence bug on right tiles, add visual language
  for "selected-left" vs "paired" vs "candidate-right", handle long
  labels, disable during submit.

## File

Modify: `lib/features/learning/presentation/renderers/matching_renderer.dart`

## BUG — fix first

Current code at ~line 104:

```dart
enabled:
    !widget.submitting && _activeLeft != null ||
    usedRight.contains(item['id']),
```

`&&` binds tighter than `||`, so this evaluates as
`(!widget.submitting && _activeLeft != null) || usedRight.contains(...)`.
Consequence: a **paired** right tile stays enabled during submit —
learner can unmatch mid-request, causing a submit payload built from a
`pairs` map that no longer matches the UI.

Fix:

```dart
final bool isUsed = usedRight.contains(item['id']);
enabled: !widget.submitting && (_activeLeft != null || isUsed),
```

This preserves the intended semantics ("right is tappable when left is
armed OR to un-match") while hard-disabling during submit.

## Contract preserved

- `{'pairs': [{'leftId': String, 'rightId': String}, ...]}` — keys must
  stay `leftId` / `rightId`.
- `leftItems[]` / `rightItems[]` from `config` (already deranged server
  side). Never read `config.pairs`.
- `widget.onInputChanged` keeps firing with `_pairs.isNotEmpty`.

## UX polish

1. SectionLabel already present — replace copy with clearer two-line
   hint: keep `'CHẠM MỤC TRÁI RỒI CHẠM MỤC PHẢI ĐỂ GHÉP'` (works).
2. `_MatchTile` updates:
   - Add distinct visual states via `AnimatedContainer` (150 ms):
     - `selected` (armed left): fill `imperialGold.withValues(alpha:0.18)`,
       border `imperialGold` 2w, tiny `Icons.arrow_right_alt` on the
       trailing edge.
     - `paired`: fill `cinnabarRed.withValues(alpha:0.08)`, border
       `cinnabarRed` 1.4w, small `Icons.link` badge 14 px.
     - `disabled` (no active left and not paired on right side):
       opacity 0.6.
   - Long labels: wrap `Text` in `Expanded` (already inside `Container`
     with `width: double.infinity` — ensure `Text` has
     `softWrap: true`, `maxLines: 4`, `overflow: ellipsis`).
   - Touch target: `padding: EdgeInsets.symmetric(horizontal: 12,
     vertical: 14)` — min height ~48 px.
3. Pairing indicator — show a small connector row when a left/right pair
   is locked: replace the plain `_MatchTile` for paired items with a
   stacked `Column` showing `label` + the matched counterpart's label in
   italic `bodySmall`. Implementation: keep two columns; on right tile,
   `paired=true` → subtitle shows the left label it is bound to (lookup
   via `_pairs.entries.firstWhere((e) => e.value == rightId)`).
4. Allow re-pairing: tap a paired right tile to **release** the match
   (current behavior — keep), AND tap a paired left tile to arm it
   again for re-assignment (new):
   - Modify `_tapLeft(id)`: if `_pairs.containsKey(id)` → set
     `_activeLeft = id` AND remove the existing pair (so re-pairing is
     one step). If `_activeLeft == id` → just disarm (toggle). If
     unpaired → arm.
5. Duplicate right prevention — already done via `_pairs.removeWhere((_,
   r) => r == id)` inside `_tapRight`; keep.
6. Add `HapticFeedback.selectionClick()` on both `_tapLeft` and
   `_tapRight`.
7. During submit (`widget.submitting == true`): all tiles get
   `enabled=false` AND opacity 0.55 — verified via the fix above +
   applying same to left tiles (already `enabled: !widget.submitting`).
8. Empty state: keep current `ActivityCard` fallback.

## Layout for long labels

- Current `Row( Expanded | Expanded )` can squeeze columns on narrow
  phones. Wrap the whole `Row` in a `LayoutBuilder`: if
  `constraints.maxWidth < 360`, render columns stacked vertically
  (left column then right column with a divider
  `Icon(Icons.arrow_downward)`). Otherwise keep side-by-side.

## Todo

- [ ] Apply parens fix to `enabled` expression.
- [ ] Add `_MatchTile` variants + AnimatedContainer + opacity-when-off.
- [ ] Show paired counterpart as subtitle on right tiles.
- [ ] Re-arm paired left on tap.
- [ ] Haptics + long-label `maxLines:4` + `LayoutBuilder` narrow
      fallback.
- [ ] Counter text `'Đã ghép x/y'` — keep, font: `labelSmall`.

## Tests (Phase 08 hooks)

- Widget test: when `submitting=true`, tapping a paired right tile does
  NOT remove the pair (regression for precedence bug).
