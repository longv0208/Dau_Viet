# ANIM-01 — Final Visual Geometry & Playback Bugfix Report

Date: 2026-10-22. Scope: ONE focused pass on Flutter mobile only —
`river_scene.dart`, `historical_animation_player.dart`,
`historical_animation_test.dart`, plan.md roadmap. No backend/admin changes.

## 1. P1 — Stakes (river_scene.dart)

- Exposure direction corrected and locked by test: canvas y grows down,
  tip is exposed iff `tip.dy < waterSurfaceY` (`stakeTipExposed`).
- `_stakeField` rewritten: 9 stakes `(x, length)`, every base anchored on
  `bedTop = 0.80h` via `stakeBaseFor` — no base floats above the bed.
- Lengths retuned to 0.16–0.24h (was 0.105–0.165, too short — zero tips
  ever exposed). Exposure condition is `length > 0.60 * waterLevel`:
  wl 0.30 → 6 tips exposed, wl 0.28 → 8, wl 0.90 → 0 submerged.
- Submerged stakes render dimmer (alpha 0.45) — distinguished by
  visibility/opacity, not only color. Exposed tips additionally get a
  white tick mark + optional red highlight ring on prediction reveal.
- All rects normalized (LTWH base→tip), no inverted bounds or invalid
  paths; labels clamped inside canvas. Still schematic, no assets.

## 2. P1 — Boats (river_scene.dart)

- Single X formula kept: `boatXFor = w * (1.05 - prog * (1.05 - endX))`
  with per-lane delays [0, 0.18, 0.36].
- `boatsObstructed` no longer changes X at all: the previous clamp
  (`x < limit ? limit : x`) teleported boats *backward* when they were
  already past the limit (at progress 0.85 free x=0.285w vs limit 0.72w
  — a 35%-of-canvas jump). `boatDisplayXFor` now returns the path X
  identically; obstruction is presentation-only (hull tilt 0.10 rad,
  direction arrow hidden). `_stakeEdgeX`/`obstructedLimitX` removed;
  `stakeFieldEdgeX` kept only as a test/inspection landmark.
- `_boatEndX` moved 0.15 → 0.50 so the configured final progress (0.85)
  lands the lead boat at x≈0.58w — inside the stake field (0.42–0.65w),
  which is the visual "stuck on stakes" beat. Sequence/steps unchanged.
- Boats float on the surface: `y = surfaceY - h*0.012`; water-level
  changes lift/lower boats, never shift them horizontally.

## 3. P2 — Playback (historical_animation_player.dart)

- Pause: `_controller.stop()` inside setState — freezes an in-flight
  tween immediately, not only the advance timer.
- Resume: `forward()` now guarded by `_controller.value > 0 && < 1` —
  a finished tween is not restarted (prevents re-drifting to the stale
  step target).
- Replay: clears `_chosenOption`, `_predictionRevealed`,
  `_highlightStakes`, `_boatsObstructed`; resets water 0.30 / boats 0;
  cancels the advance timer; never submits.
- Reveal during a tween: `_controller.stop()` before forcing low-water
  state so the in-flight tween cannot overwrite the reveal.
- Manual slider: `_setWater` already stops controller + timer — manual
  input always wins. Skip never submits (existing test kept).

## 4. Tests added (historical_animation_test.dart, 21 → 37)

- Stake geometry (5): low water exposes tips; high water submerges all;
  exposed count monotonically non-increasing; every base on the bed;
  normalized bounds, no inverted stakes.
- Boat continuity (5): obstruction never shifts X; toggling never moves
  position; final progress lands lead boat inside the field; steps 3–5
  coherent; water level never shifts boats horizontally.
- Player playback (5): pause freezes in-flight tween + resume continues;
  replay clears prediction + restores initial scene; reveal during tween
  not overwritten; manual slider wins over tween; (existing skip/READ-ack
  tests cover the rest).
- Real small-screen (3): `tester.view.physicalSize` + `devicePixelRatio`
  at 320/360/390 logical px, `addTearDown(reset)` — replaces the fake
  MediaQuery-only small-screen test.

## 5. Generality for ANIM-02

Engine stays generic: player/controls/prediction untouched by scene
content; river logic isolated in `scenes/river_scene.dart` +
`content/bach_dang_938_tide_v1.dart`. Smallest extension point
documented in plan.md: new painter + new typed definition + registry
entry. MapScene intentionally not implemented. No physics engine.

## 6. Verification actually run

- `dart format lib/.../animations test/.../historical_animation_test.dart` — clean
- `flutter analyze` — No issues found
- `flutter test test/learning/historical_animation_test.dart` — 37/37 pass
- `flutter test test/learning` (all learning incl. READ renderer tests) — 98/98 pass
- `git diff --check` — clean
- No Playwright, no browser E2E, no APK, no commit/push (per constraints)

## 7. Out of scope / unchanged

Backend READ semantics, `config.animationKey` contract, admin editor,
snapshot behavior, learner projection, lesson progression, MCQ grading,
rewards/inventory, historical map, auth, published versions — untouched.

## Unresolved questions

- `_boatEndX = 0.50` places the lead boat mid-field at final progress;
  if art direction prefers boats stopping at the field edge instead,
  tune `_boatEndX`/`boatProgress` targets only — the single-formula
  contract does not change.
