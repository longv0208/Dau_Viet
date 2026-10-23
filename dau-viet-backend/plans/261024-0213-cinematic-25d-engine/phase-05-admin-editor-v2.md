# Phase 05 — Admin editor: camera, tracks, effects, audio

## Context

- Admin types: `src/features/animations/animation-types.ts`.
- Editor: `scene-editor.tsx` orchestrates sections in `scene-editor/editor-sections.tsx`, `timeline-section.tsx`, `renderer-editors.tsx`, `scene-preview.tsx`, `publish-section.tsx`.
- Editor uses `useSceneEditor` hook, drafts as `manifest` JSON object → PATCH `draftJson`.
- Preview parity: `scene-preview.tsx` already mirrors Flutter painter geometry in SVG.

## Overview

- Priority: P1
- Status: pending
- Expose v2 fields (camera, tracks, effects, audio, environment) in the no-code editor; keep preview parity with Flutter.

## Key insights

- Editor sections are flat, collapsible. Add new sections rather than rework layout: `CameraSection`, `TracksSection`, `EffectsSection`, `AudioSection`, `EnvironmentSection` (RIVER only).
- `ManifestObject` already has `position`, `scale`, `rotation`, `visible`, `layer` — tracks keyframe edits ride on these object ids.
- `SUPPORTED_ASSET_ROLES` currently `{BACKGROUND, OBJECT}` — extend to `{..., AUDIO}` once backend accepts audio mime (Phase 01).
- Preview must implement camera transform (scale + translate the SVG container) and keyframe evaluation — share evaluator spec via small pure-TS module mirroring Dart semantics.

## Requirements

- Types: extend `AnimationManifest` with `camera?`, `tracks?`, `effects?`, `audio?`, `environment?` matching backend schema exactly.
- `CameraSection`: edit `camera.initial` (x, y, zoom sliders + numeric inputs) and a per-step `camera.steps[i]` block — for each step, override `target` (x/y/zoom/focus) + `durationMs` + `easing`.
- `TracksSection`: list tracks; each track picks `objectId` (dropdown of `objects[]`), `property` (dropdown of position/scale/rotation/opacity/visible), and a list of keyframes `{tMs, value, easing?}` — value widget depends on property (x/y pair, scalar, or toggle).
- `EffectsSection`: scene-level `effects[]` array — add/remove entries, pick `type` (dropdown of whitelist), edit `durationMs`, edit `params` as key/value JSON-lite form.
- `AudioSection`: manage `audio[]` — pick `stepId` from dropdown of `steps[]`, `assetRef` from `assets[]` filtered to `role=AUDIO`, `cue` (ENTER/EXIT/LOOP), `volume` slider, `fadeMs` number.
- `EnvironmentSection` (RIVER_TIDE only): `waterLevel`, `mist`, `glow` sliders.
- Update `SUPPORTED_ASSET_ROLES` to include `AUDIO` once backend mime whitelist is extended.
- Preview parity: `scene-preview.tsx` must (a) apply camera transform to the SVG stage; (b) evaluate keyframe tracks at the "current global tMs"; (c) render mist/glow/fade overlays; (d) indicate audio cues (icon, no autoplay in preview — autoplay would be obnoxious in an admin tool).

## Architecture

```
animation-types.ts
  + CameraTrack / CameraStep / CameraState types
  + ObjectTrack / Keyframe types
  + SceneEffect / AudioCue / Environment types
  + V2_TOP_LEVEL_KEYS constant

editor-sections.tsx
  + CameraSection, TracksSection, EffectsSection, AudioSection, EnvironmentSection

scene-editor.tsx
  + mount new sections (conditional on rendererCode for environment)

scene-preview.tsx
  + applyCameraTransform(svg)
  + evaluateTracks(globalTMs)
  + renderEffectsOverlays(effects, environment)
  + audio icon badges on the active step
```

Modify:
- `dau-viet-admin/src/features/animations/animation-types.ts`
- `dau-viet-admin/src/features/animations/animation-api.ts` (no shape change needed — manifest is opaque JSON to API; verify only)
- `dau-viet-admin/src/features/animations/scene-editor.tsx`
- `dau-viet-admin/src/features/animations/scene-editor/editor-sections.tsx` (add new sections here OR split into new files — see below)
- `dau-viet-admin/src/features/animations/scene-editor/scene-preview.tsx`
- `dau-viet-admin/src/features/animations/scene-editor/renderer-editors.tsx` (add `EnvironmentSection` here for RIVER consistency)

Create (keep `editor-sections.tsx` under ~800 lines — split):
- `dau-viet-admin/src/features/animations/scene-editor/camera-section.tsx`
- `dau-viet-admin/src/features/animations/scene-editor/tracks-section.tsx`
- `dau-viet-admin/src/features/animations/scene-editor/effects-section.tsx`
- `dau-viet-admin/src/features/animations/scene-editor/audio-section.tsx`
- `dau-viet-admin/src/features/animations/preview/cinematic-eval.ts` — pure TS keyframe + camera evaluator (mirrors Dart semantics).

Tests:
- `dau-viet-admin/src/features/animations/animation-types.test.ts` (extend)
- `dau-viet-admin/src/features/animations/preview/cinematic-eval.test.ts`
- `dau-viet-admin/src/features/animations/scene-preview.test.tsx` (extend)

## Implementation steps

1. Extend `animation-types.ts` with v2 types + constants; bump `emptyManifest` to emit `schemaVersion: 2` when caller wants v2 (or keep 1 by default — let the validator gate).
2. Create `cinematic-eval.ts`: `evalTrackAtTMs(track, tMs)`, `evalCameraAtStep(camera, stepIndex, tMsInStep)` — pure functions.
3. Create section components (camera, tracks, effects, audio, environment) following existing Section/SectionProps pattern; register in `scene-editor.tsx`.
4. Update `SUPPORTED_ASSET_ROLES` in `editor-sections.tsx` to add `AUDIO` (with "(chưa hỗ trợ)" disabled until backend ready — actually enable since Phase 01 lands first).
5. Update `scene-preview.tsx`: wrap stage `<div>` in a transform container driven by current camera; evaluate tracks into per-object visual overrides; render overlays for mist/glow/fade; show audio badge.
6. Tests for `cinematic-eval` + types parsing.
7. `npm run typecheck`, `npm run test`.

## Todo list

- [ ] `animation-types.ts` v2 types + constants
- [ ] `cinematic-eval.ts` + tests
- [ ] `camera-section.tsx`
- [ ] `tracks-section.tsx`
- [ ] `effects-section.tsx`
- [ ] `audio-section.tsx`
- [ ] `EnvironmentSection` in `renderer-editors.tsx` (RIVER only)
- [ ] `scene-editor.tsx` registers new sections
- [ ] `scene-preview.tsx` camera+tracks+effects+audio badges
- [ ] `SUPPORTED_ASSET_ROLES` includes `AUDIO`
- [ ] `npm run typecheck && npm run test` green

## Success criteria

- Admin can build a v2 manifest end-to-end without touching JSON: camera pan+zoom, keyframed object motion, mist overlay, audio ENTER cue.
- Preview visually matches what Flutter renders for same manifest (verified manually + unit tests on evaluator).
- `vitest` suite passes; typecheck clean.
- Publishing a v2 manifest produces schemaVersion=2 row in `animation_scene_versions`.

## Risks

- Preview parity drift: keep preview's evaluator a literal port of Dart's `cinematic_state.dart` (same formula, same edge cases). Document this in `cinematic-eval.ts` header.
- Editor UX complexity — keep sections collapsed by default.

## Security

- Audio assets fetched via existing `/admin/assets/{id}/content` BFF.
- No new upload paths.
