# Interactive Historical Animations — ANIM-01

## Overview

Core engine + first scene for interactive historical animations inside READ
activities. Learners manipulate a schematic river scene (water level slider,
step narration, prediction checkpoint) to understand the Bach Dang 938 tactic.
ANIM-01 only — no animation builder, JSON scripting, new ActivityType, or
external game/animation engines.

## Status

| Phase | Status |
|-------|--------|
| Flutter animation core (definition/registry/player/controls) | Done |
| RiverScene painter + `bach_dang_938_tide_v1` content | Done |
| ReadRenderer integration (`config.animationKey`) | Done |
| Backend validation (ReadValidator.animationKey) | Done |
| Admin editor field + honest preview line | Done |
| Tests: 20 Flutter + 6 backend + 6 admin | Done |
| Attach scene to a live Bạch Đằng READ lesson | Manual step via Admin |

## Contract

- `config.animationKey`: optional string on READ activities.
  Backend `ReadValidator` enforces `[a-z0-9]+(_[a-z0-9]+){0,7}`, max 80 chars
  (INVALID_TYPE / INVALID_ID). Survives draft → snapshot → learner projection
  (not a LEARNER_HIDDEN_KEYS leaf name).
- Flutter `HistoricalAnimationRegistry.resolve(key)` → typed
  `HistoricalAnimationDefinition` or null. Unknown/missing key → plain READ,
  never a crash or a substituted scene.

## Invariants

- Presentation-only: prediction and slider never POST; READ acknowledgement
  still submits `{}` through the normal handler. No EXP/score/progress effect.
- All scene state is local per widget instance (keyed by animationKey +
  activity id); dispose cancels timer + controller.
- Reduced-motion: steps jump statically; auto-advance uses a 4s reading delay.
- Schematic, not reconstruction: disclaimer line is always rendered:
  "Sơ đồ minh họa chiến thuật, không theo tỉ lệ và không phải phục dựng
  chính xác trận đánh." Source: Vietnam National Museum of History article.
- No event-specific branches in generic renderers/handlers.

## Files

- `dau-viet-mobile/lib/features/learning/presentation/animations/`
  - `historical_animation_definition.dart` — step/prediction/definition/painter base
  - `historical_animation_registry.dart` — static typed registry
  - `historical_animation_player.dart` — stateful player (controller + timer)
  - `historical_animation_controls.dart` — play/pause/prev/next/replay/skip
  - `scenes/river_scene.dart` — water/stakes/boats painter
  - `content/bach_dang_938_tide_v1.dart` — 6-step scene definition
- `read_renderer.dart` — resolves `config.animationKey`, keyed player
- `dau-viet-backend/.../SimpleActivityValidators.java` — ReadValidator check
- `dau-viet-admin/.../read-editor.tsx` — "Mã hoạt họa (Flutter)" input
- `dau-viet-admin/.../text-renderers.tsx` — preview notice (no Flutter playback)

## Next (ANIM-02+)

- New scenes register a second `HistoricalAnimationDefinition` keyed by a new
  versioned animationKey; MapScene reuse path intentionally left open.
