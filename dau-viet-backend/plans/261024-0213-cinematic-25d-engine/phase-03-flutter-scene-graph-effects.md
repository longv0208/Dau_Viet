# Phase 03 — Flutter runtime: layered scene graph + environment effects

## Context

- Painters (`RiverScenePainter`, `MapScenePainter`) draw everything via `CustomPainter.paint`.
- `ManifestAssetLayers` wraps the painter with static background + object images.
- Phase 02 introduces `CameraState`/`ObjectVisualState`/`effects`/`environment` parsing.

## Overview

- Priority: P1
- Status: pending
- Layer painters above/below manifest-driven image layers so scenes feel "2.5D". Add whitelisted environment effects (water ripple, mist, glow, route reveal, fade) driven by `effects[]` + `environment` per scene.

## Key insights

- "Layered scene graph" here means: Background image → Painter canvas → Object images → Effects overlays → Caption/UI. We do NOT need a real ECS scene graph — just Z-ordering + per-layer visibility driven by `layer`/`visible` fields.
- Effects are painter-driven overlays (a small `EffectPainter` per type) OR widget overlays (MIST/GLOW can be `Container` with gradient). Prefer painter for effect types tied to scene geometry (WATER_RIPPLE, ROUTE_REVEAL); prefer widget overlays for full-screen effects (MIST, GLOW, FADE).
- `environment` (RIVER_TIDE): `waterLevel`, `mist`, `glow` ambient — apply at seed, not as a step target.

## Requirements

- Z-order contract: `objects[].layer` already exists; object images sort by `layer`. Painter canvas sits at fixed layer (below `layer >= 0` objects, above `layer < 0`? Or split painters into below/above). **Decision**: keep single painter canvas at implicit layer 0 — keeps migration simple, objects already have explicit `layer` to choose above/below.
- `SceneEffectDto { type, durationMs?, params? }` — applied at step entry:
  - `WATER_RIPPLE` — RIVER only; painter-driven ripple ring at `params.x,params.y` for `durationMs`.
  - `MIST` — gradient overlay at top of canvas, intensity `params.intensity` 0..1.
  - `GLOW` — radial glow around `params.x,params.y` or `params.objectId`, intensity.
  - `ROUTE_REVEAL` — JOURNEY_MAP; equivalent to existing `routeProgress` ramp but with explicit duration/easing hint.
  - `FADE_IN` / `FADE_OUT` — full-canvas opacity ramp.
- `environment` block applied at player init (not per-step): `waterLevel` → painter seed; `mist`/`glow` → persistent overlay intensity.
- Reduced-motion: effects that are pure decoration (MIST/GLOW) may still render statically; motion effects (WATER_RIPPLE, ROUTE_REVEAL, FADE_*) jump to end-state instantly.

## Architecture

```
ManifestAssetLayers (modified)
  children:
    - Background image             (existing, layer -inf)
    - EnvironmentOverlay (mist/glow) (new, driven by EnvironmentDto)
    - Painter canvas               (existing, layer 0)
    - Object images sorted by layer (existing, layer >= 0 above painter)
    - EffectPainter overlays       (new, layer +inf)
    - Caption/UI                   (outside)

EffectPainter implements CustomPainter
  - RiverRipplePainter { center, progress, color }
  - RouteRevealPainter { painter, routeId, tMs }
  - FadePainter { opacity }
```

Modify:
- `dau-viet-mobile/lib/features/learning/presentation/animations/widgets/manifest_asset_layers.dart` — add `effects`/`environment`/`visualStates` wiring.
- `dau-viet-mobile/lib/features/learning/presentation/animations/historical_animation_player.dart` — drive effect painters from step.effects + environment.

Create (all generic, manifest-driven):
- `dau-viet-mobile/lib/features/learning/presentation/animations/effects/effect_painters.dart` — `RiverRipplePainter`, `MistPainter`, `GlowPainter`, `FadePainter`.
- `dau-viet-mobile/lib/features/learning/presentation/animations/effects/environment_overlay.dart` — widget wrapper for ambient mist/glow.

Tests:
- `dau-viet-mobile/test/features/learning/presentation/animations/effects/effect_painters_test.dart`

## Implementation steps

1. `effect_painters.dart`: each painter takes `progress`/`intensity`/`center`; no event branching.
2. `environment_overlay.dart`: stateless widget reading `EnvironmentDto`; renders `Mist`/`Glow` layers.
3. `ManifestAssetLayers`: accept `effects`, `environment`, `visualStates`; construct overlay widgets.
4. Player: at `_applyStep`, for each `step.effects`, look up type → instantiate painter → animate via master controller or `Timer` for durationMs.
5. Environment: on `initState`, seed painter `waterLevel` and overlay intensity.
6. Reduced-motion: skip effects tween; render end-state.
7. Tests: painter hits `paint()` with given params; overlay shows/hides; reduced-motion path.

## Todo list

- [ ] `effect_painters.dart` (WATER_RIPPLE, MIST, GLOW, FADE_IN, FADE_OUT)
- [ ] `environment_overlay.dart` (mist/glow ambient)
- [ ] `ManifestAssetLayers` Z-order + new params
- [ ] Player wires `step.effects` → painter overlay lifecycle
- [ ] Environment seeding at init
- [ ] Reduced-motion path
- [ ] Widget tests

## Success criteria

- A step with `effects: [{type:"MIST",params:{intensity:0.6}}]` shows mist overlay only during that step.
- `environment.mist` persists across all steps.
- WATER_RIPPLE renders at declared x,y and fades.
- Reduced-motion: no animation, end-state shown.
- All prior tests still pass.

## Risks

- Overlays can obscure painter content — keep alpha/intensity ≤ 0.5 default.
- Painter-driven effects need `setState`/repaint — use `CustomPainter` listening to master controller; avoid `setState` per frame.

## Security

- Manifest-driven; params bounded by validator.
