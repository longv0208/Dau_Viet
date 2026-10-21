# Phase 04 — DRAG_ORDER polish

## Overview

- Priority: P2
- Status: pending
- Goal: smoother reorder UX, clearer numbered positions, working
  a11y up/down buttons, no overflow on long labels.

## File

Modify: `lib/features/learning/presentation/renderers/drag_order_renderer.dart`

## Contract preserved

- Submit `{'orderedIds': List<String>}` — never `expectedOrder`.
- `_initialOrder` snapshot + `_reportDirty` diff — keep.

## Current issues

1. `ReorderableListView.builder` + `buildDefaultDragHandles: false` works
   but each row only exposes the `drag_indicator` icon as the drag
   handle — long-press on the tile body does nothing.
2. No visible position number.
3. Long labels can overflow — `Text` inside `Expanded` is fine but no
   `maxLines` cap.
4. No proxyDecorator / drop animation polish.
5. `ReorderableDragStartListener` uses `enabled` flag — verify it
   actually disables while submitting; current signature uses
   `enabled:` correctly.

## Changes

1. Position badge: prepend a circle `Container(width:26,height:26,
   decoration: circle cinnabarRed.withValues(alpha:0.12) + border
   cinnabarRed 1.2)` containing `Text('${index+1}', labelMedium bold
   cinnabarRed)`. Update on every rebuild — cheap.
2. ReorderableListView:
   - `proxyDecorator: (child, index, animation) => AnimatedBuilder`
     that scales 1.0→1.03 and adds a subtle `heritageShadow` — reuse
     `DauVietColors.heritageShadow`.
   - `onReorderStart: (_) => HapticFeedback.lightImpact()`.
   - Keep `onReorderItem` (NOT `onReorder`) — already correct index
     remap for `ReorderableListView.builder` on Flutter 3.22+.
   - Keep `physics: NeverScrollableScrollPhysics()` + `shrinkWrap: true`
     (inside player's SingleChildScrollView).
3. `_OrderTile` improvements:
   - Whole tile becomes a `ReorderableDragStartListener` — i.e. wrap
     outer `Container` (not just the icon) in the listener so the tile
     body can initiate the drag. Keep the icon purely as a visual hint.
   - `Semantics(label: 'Vị trí ${index+1}: $label', hint: 'Kéo để di
     chuyển hoặc dùng nút lên/xuống')`.
   - Long-label guard: `Text(label, maxLines: 4, overflow:
     TextOverflow.ellipsis, softWrap: true)`.
   - AnimatedContainer: background brightens slightly while
     `enabled=false` (submitting) — opacity 0.6.
4. Up/down buttons: keep two `IconButton`s; add `disabledColor:
   DauVietColors.inkMuted.withValues(alpha:0.4)`; add
   `HapticFeedback.selectionClick()` before `_move`.
5. Edge cases:
   - First item → `onUp` is no-op (`_move` already guards `target<0`);
     also set `onPressed: index==0 ? null : onUp` so the button LOOKS
     disabled. Same for `index == _items.length-1` on `onDown`.
   - Empty state unchanged.

## Todo

- [ ] Position badge circle with `index+1`.
- [ ] `proxyDecorator` scale/shadow + `onReorderStart` haptic.
- [ ] Drag handle covers whole tile.
- [ ] Long-label `maxLines:4` ellipsis.
- [ ] Disable edge up/down buttons.
- [ ] Opacity on `submitting`.

## Risks

- `ReorderableListView` keys: `ValueKey(id)` already stable — keep.
- Changing drag handle from icon to whole tile means the icon is no
  longer interactive — remove `InkWell`/extra listener on icon.
