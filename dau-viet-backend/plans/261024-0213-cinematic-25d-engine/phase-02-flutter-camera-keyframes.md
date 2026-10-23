# Phase 02 — Flutter runtime: camera + keyframe engine

## Context

- DTO at `lib/features/learning/presentation/animations/runtime/animation_manifest_dto.dart`.
- Player at `historical_animation_player.dart` — single `AnimationController`, `_stepCurve`, frozen `_tweenFrom` snapshot per step.
- Painters `RiverScenePainter` / `MapScenePainter` are `CustomPainter + ChangeNotifier`.
- Reduced-motion uses `MediaQuery.disableAnimations` → jump to `t=1`.

## Overview

- Priority: P1
- Status: pending
- Add `camera` (pan/zoom/focus) and `tracks` (per-object keyframe motion) as a second, layered animation channel. The existing step `targetState` tween remains the scene-content channel; camera+tracks are an orthogonal "cinematography" channel.

## Key insights

- Don't rebuild the player: extend `HistoricalAnimationPlayer` with a second `AnimationController` for camera, plus a keyframe evaluator that maps `tMs → property value` per object.
- Camera state lives outside painter (it's viewport transform, not scene state). Apply via `Transform` widget on the `CustomPaint`.
- Keyframes write to a per-object overlay state — `Map<String, ObjectVisualState>` consumed by `ManifestAssetLayers` (position/scale/rotation/opacity/visible) and optionally by painter-aware objects later.
- Reduced-motion: jump to final camera + final keyframe values per step (no tween).

## Requirements

- Parse `camera.initial` and `camera.steps[]` in `AnimationManifestDto`.
- Parse `tracks[]` with `keyframes[]` into typed `ObjectTrack`/`Keyframe` DTOs.
- `CameraState { Offset center; double zoom; String? focusObjectId; String? focusLocationId; }` lerp-able.
- Per-object `ObjectVisualState { Offset position; double scale; double rotation; double opacity; bool visible; }` lerp-able; defaults derived from `objects[]` entry.
- When step has `camera.steps[i]` → camera tweens during that step using step's `durationMs`/`easing`.
- Keyframe evaluation: `tMs` is absolute within the whole scene timeline (sum of `durationMs`); player must map "current global position" → `tMs` per object.
- `ManifestAssetLayers` consumes per-object visual state (replace static position/scale/visible).

## Architecture

```
AnimationManifestDto
  + camera: CameraTrackDto?
  + tracks: List<ObjectTrackDto>
  + effects: List<SceneEffectDto>   // parsed here, applied Phase 03
  + audio:  List<AudioCueDto>      // parsed here, applied Phase 04
  + environment: EnvironmentDto?    // parsed here, applied Phase 03

class CameraTrackDto { CameraState initial; List<CameraStepDto> steps; }
class CameraStepDto { CameraState target; int? durationMs; String easing; }
class CameraState { Offset center; double zoom; String? focusRef; }
class ObjectTrackDto { String objectId; String property; List<KeyframeDto> keyframes; }
class KeyframeDto { int tMs; Object value; String? easing; }
```

New file (Flutter, generic — no per-event branching):
- `lib/features/learning/presentation/animations/runtime/cinematic_state.dart` — `CameraState`, `ObjectVisualState`, `Keyframe` evaluator (`valueAt(tMs)`).

Modify:
- `lib/features/learning/presentation/animations/runtime/animation_manifest_dto.dart` — parse v2 fields.
- `lib/features/learning/presentation/animations/historical_animation_player.dart` — second controller, camera + tracks evaluation, expose `CameraState`/`Map<String,ObjectVisualState>` via `ValueNotifier` or as part of painter state.
- `lib/features/learning/presentation/animations/widgets/manifest_asset_layers.dart` — read per-object visual state instead of static `o.position`/`o.scale`.

## Related code files

Modify:
- `dau-viet-mobile/lib/features/learning/presentation/animations/runtime/animation_manifest_dto.dart`
- `dau-viet-mobile/lib/features/learning/presentation/animations/historical_animation_player.dart`
- `dau-viet-mobile/lib/features/learning/presentation/animations/widgets/manifest_asset_layers.dart`

Create:
- `dau-viet-mobile/lib/features/learning/presentation/animations/runtime/cinematic_state.dart`

Tests:
- `dau-viet-mobile/test/features/learning/presentation/animations/runtime/cinematic_state_test.dart`
- `dau-viet-mobile/test/features/learning/presentation/animations/historical_animation_player_test.dart` (extend)

## Implementation steps

1. Extend `AnimationManifestDto.fromJson` with optional `camera`, `tracks`, `effects`, `audio`, `environment` fields (parse-or-default; never throw).
2. Add `CameraState.lerp`, `ObjectVisualState.lerp`, `Keyframe.evaluatorFor(property)` — pure Dart, unit-testable.
3. Player: maintain `_cameraCtrl` + `_cameraFrom`/`_cameraTarget` similar to `_tweenFrom`; tick drives camera transform.
4. Player: compute `globalTMs = elapsed time since scene start` (or sum of completed `durationMs` + current controller progress × current step duration); evaluate every track at `globalTMs`.
5. Wrap `CustomPaint` with `Transform` applying `camera.zoom` + translation from `camera.center`.
6. `ManifestAssetLayers` gets a new optional `visualStates` param; falls back to object defaults.
7. Reduced-motion: jump camera+tracks to step's target on applyStep.
8. Tests: lerp purity, keyframe eval at boundaries, camera focus → center math, reduced-motion skip, dispose safety.

## Todo list

- [ ] DTO parses `camera`, `tracks`, `effects`, `audio`, `environment`
- [ ] `cinematic_state.dart` pure-Dart evaluators + tests
- [ ] Player second controller + camera transform wiring
- [ ] `ManifestAssetLayers` consumes `visualStates`
- [ ] Reduced-motion jump applied to camera + tracks
- [ ] `flutter test` green

## Success criteria

- A v2 manifest with camera pan+zoom between two steps plays correctly in widget test.
- A track animating `position.x` of an OBJECT asset moves smoothly across the canvas.
- Reduced-motion jumps to final values without tween.
- All 278 existing animation tests still pass.

## Risks

- Two concurrent `AnimationController`s per player → memory/fan-out risk; mitigate: reuse single controller and derive camera channel from the same tick (preferred — see note below).

**Note on controller reuse**: prefer ONE controller driving both scene-state and camera channels (a "master timeline"), with keyframe evaluators sampled at `globalTMs`. Simpler lifecycle, one dispose, one reduced-motion gate.

## Security

- All values are whitelisted/bounded; no code execution.
- Audio not implemented here (Phase 04).
