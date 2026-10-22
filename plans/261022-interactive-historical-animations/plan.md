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
| Visual geometry + playback bugfix (stakes/boats/pause/replay/reveal) | Done |
| Resume-after-interaction fix (`_tweenPaused`) | Done |
| **ANIM-02**: `SceneTransition` contract + MapScene (marker/route/highlight) | Done |
| ANIM-02 scenes: `hai_ba_trung_40_uprising_v1` + `ly_thai_to_1010_relocation_v1` | Done |
| Marker tap → info panel (`LocationInfoPanel` + `MapMarkerOverlay`) | Done |
| Shared transition fix: frozen-snapshot `applyFrom` + marker pause/settle | Done |
| **POLISH-BD-01**: `bach_dang_938_tide_v1` production — decoy/counterattack/sequence-summary | Done |
| Tests: 77 Flutter + 6 backend + 6 admin | Done |
| Attach scenes to live READ lessons | Manual step via Admin |

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

## Roadmap (source of truth for subsequent prompts)

Learning rhythm for every scene: **Observe → Predict → Explore → Feedback
→ Understand**. Animation is a presentation layer inside READ — optional
for learners, never affecting grading, EXP, rewards or progression.

- **ANIM-01 — Core + Bạch Đằng 938** (done): generic engine
  (definition/registry/player/controls/prediction), RiverScene painter,
  `config.animationKey` contract end-to-end (backend validation → admin
  editor → learner projection → Flutter resolve).
- **ANIM-02 — Map scenes** (done): `SceneTransition` typed contract —
  each step carries a scene-specific target (`RiverSceneState` /
  `MapSceneState`), player only lerps. `MapScenePainter` + interactive
  marker overlay (≥44px, semantics) + `LocationInfoPanel`. Two scenes:
  `hai_ba_trung_40_uprising_v1` (6 steps), `ly_thai_to_1010_relocation_v1`
  (5 steps). No river-property misuse — map state is its own typed class.
- **ANIM-FOCUS-01 — Stabilization (done)**: frozen-snapshot
  interpolation (`state(t) = lerp(frozenStart, target, t)` — frame-count
  independent), marker tap = pause + settle step, navigation/replay
  clears stale selection, reveal không bị tween cũ ghi đè.
- **ANIM-POLISH — Scene polish + lesson attach (in progress)**:
  `bach_dang_938_tide_v1` đạt production (POLISH-BD-01: dụ địch,
  phản công phối hợp, sơ đồ chuỗi tổng kết bước 6). Tiếp theo:
  polish `hai_ba_trung_40_uprising_v1` tương tự, gắn vào READ thật
  qua Admin. `ly_thai_to_1010_relocation_v1` giữ nguyên — không
  mở rộng.
- **ANIM-03 — Object exploration + timeline + more lessons** (deferred):
  rotate/zoom artifact, timeline scrubbing. Hoãn tới khi 2 scene ưu
  tiên đạt production quality.
- **ANIM-04 — Polish** (deferred): turtle mascot reactions, UX polish,
  accessibility pass, performance budget review.

## Extension point (smallest, for ANIM-02)

`HistoricalAnimationRegistry.resolve(key)` returns any
`HistoricalAnimationDefinition`; the player only talks to
`HistoricalScenePainter` setters (waterLevel / boatProgress /
boatsObstructed / highlightStakes). A map scene adds its own painter +
definition + registry entry — river-specific logic stays inside
`scenes/river_scene.dart` and `content/bach_dang_938_tide_v1.dart`.
