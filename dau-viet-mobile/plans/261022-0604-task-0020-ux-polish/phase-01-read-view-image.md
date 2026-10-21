# Phase 01 — READ + VIEW_IMAGE polish

## Overview

- Priority: P1
- Status: pending
- Goal: better typography & scroll behavior for READ, image polish + zoom
  for VIEW_IMAGE, graceful missing-image handling for both.

## Files

Modify:
- `lib/features/learning/presentation/renderers/read_renderer.dart`
- `lib/features/learning/presentation/renderers/view_image_renderer.dart`
- `lib/features/learning/presentation/renderers/learning_asset_image.dart`

Create:
- `lib/features/learning/presentation/renderers/fullscreen_image_viewer.dart`
  (private helper used only by view_image + tap-to-zoom from
  `LearningAssetImage`).

## Contracts / invariants

- READ submits `const {}` — no answer fields.
- VIEW_IMAGE submits `const {}` — no answer fields.
- `LearningAssetImage` public API keeps current signature (`assetId`,
  `altText`, `height`, `fit`) — VERIFICATION / HYPOTHESIS / evidence tiles
  do not use it yet, so changes are internal.
- `content.assetById(assetId)` is the only asset metadata source. Fields
  that exist in snapshot: `id`, `altText`, plus whatever the projection
  emits — do not invent new fields; read `altText`, `caption`, `source`
  defensively via `as String?`.

## Changes — read_renderer.dart

1. Extract paragraph rendering into a small `_Body` widget. Keep
   `SelectableText` for copy support.
2. Typography bump: title uses
   `DauVietTypography.headlineSmall.copyWith(fontSize: 18)` (serif) instead
   of `headlineMedium.copyWith(fontSize: 17)` — visually tighter.
3. Paragraph style: `bodyLarge.copyWith(height: 1.65)` for the first body
   paragraph and `bodyMedium.copyWith(height: 1.6)` for `paragraphs[]`
   entries — slight hierarchy between led-in and body.
4. Wrap the whole `ActivityCard` content in a
   `FadeIn` effect: `AnimatedOpacity` driven by a 200 ms timer in
   `initState` or use `TweenAnimationBuilder<double>(tween: 0..1,
   duration: 250ms, curve: easeOut)` — cheap, no extra dep.
5. Wrap paragraphs list in `ListView.separated` *only if* currently
   overflowing — current impl uses `Column(...blocks)` inside a
   `SingleChildScrollView` (parent); keep as `Column` but add
   `TextAlign.justify` if `paragraphs.length > 1` for a book feel.
6. Submit bar stays the same.

## Changes — learning_asset_image.dart

1. Add `onTap` optional field — when non-null and image loaded
   successfully, wrap `ClipRRect`+`Image.memory` in `InkWell(onTap: onTap)`.
2. Loading state: replace spinner with shimmering placeholder — reuse
   existing `_frame()` with a small `AnimatedOpacity` pulsing container or
   simply keep `CircularProgressIndicator(strokeWidth: 2)` plus
   `Semantics(label: altText ?? 'Đang tải hình')`.
3. Error state: same as today — `_Fallback` already shows
   `broken_image_outlined` + `altText`. Keep.
4. Memory caching: `Image.memory` already caches in-memory; do NOT add a
   new dep. If the same `assetId` is fetched twice in same session, use a
   tiny `static final Map<String, Uint8List> _cache` with
   `if (_cache.containsKey(assetId)) return SynchronousFuture(_cache[assetId])`.
   Cap at 8 entries — evict oldest via `LinkedHashMap` (dart:collection).
5. Height contract: keep param `height`; default stays null. Allow
   `width: double.infinity` only.

## Changes — view_image_renderer.dart

1. Build a header line above image: if `caption != null` render
   `DauVietTypography.labelSmall` section label `"QUAN SÁT HÌNH ẢNH"`,
   caption already rendered below the image. If asset metadata has
   `source` (Map with `title`/`author` or a String) render
   `Nguồn: {sourceText}` line under caption in italic `bodySmall` (reuse
   the same source-resolution logic as `_EvidenceTile` — extract into
   `renderer_base.dart` helper `String? evidenceSourceText(Map<String,
   dynamic>? e)` so both tiles and view_image share it).
2. Wrap `LearningAssetImage` in `InkWell` → push
   `FullscreenImageViewer(assetId, altText, heroTag: assetId)` via
   `Navigator.of(context).push(MaterialPageRoute(...))`. Wrap both the
   inline `Image.memory` and the fullscreen image in `Hero(tag: assetId)`.
3. Fullscreen viewer: new file `fullscreen_image_viewer.dart`:
   - `ConsumerWidget` that refetches bytes via the same repo call —
     reuse a `static Uint8List?` cache from `LearningAssetImage` (expose
     a `static Future<Uint8List> loadBytes(WidgetRef, String assetId)`).
   - Scaffold with black background, appBar-less, tap-outside or back
     button pops.
   - Body: `InteractiveViewer(maxScale: 4.0, minScale: 0.5, child:
     Image.memory(bytes, fit: BoxFit.contain))` centered.
   - Bottom caption bar with `altText` / `sourceText` in white on 60%
     black overlay.
   - Respect `MediaQuery.of(context).disableAnimations` — disable `Hero`
     flight via `Hero(tag: ..., enabled: !reduced)`.
4. Submit bar unchanged.

## Tests

Phase 08 will add focused tests; this phase just keeps code compilable.

## Todo

- [ ] Extract `evidenceSourceText` helper into `renderer_base.dart`.
- [ ] Update `LearningAssetImage` (cache, optional onTap, Hero tag).
- [ ] Create `fullscreen_image_viewer.dart`.
- [ ] Update `read_renderer.dart` typography + fade-in.
- [ ] Update `view_image_renderer.dart` with source line + zoom hook.
- [ ] `dart format` + `flutter analyze` green.

## Risks

- `Hero` across Navigator: ensure only ONE `Hero` per `assetId` per
  screen — VIEW_IMAGE has only one image so fine. If multiple
  VIEW_IMAGEs ever render together, hero tag must include `activity.id`.
- `SynchronousFuture` import from `package:flutter/foundation.dart`.
