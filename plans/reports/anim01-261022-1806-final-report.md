# ANIM-01 — Final Report: Interactive Historical Animation Core + Bạch Đằng 938

## Scope shipped

ANIM-01 only. Shared Flutter animation core + `bach_dang_938_tide_v1` scene,
`config.animationKey` contract backend→admin→mobile. No builder, no JSON
scripting, no new ActivityType, no Flame/Rive.

## Files created

- `dau-viet-mobile/lib/features/learning/presentation/animations/historical_animation_definition.dart` — step/prediction/definition + `HistoricalScenePainter` base (`with ChangeNotifier`, notifying setters)
- `.../animations/historical_animation_registry.dart` — typed static registry
- `.../animations/historical_animation_player.dart` — player (controller + advance timer, ~265 LOC)
- `.../animations/historical_animation_controls.dart` — play/pause/prev/next/replay/skip
- `.../animations/widgets/water_level_control.dart` — slider + Nước dâng/Nước rút presets
- `.../animations/widgets/prediction_block.dart` — ungraded prediction UI
- `.../animations/widgets/skipped_scene.dart` — static skip placeholder
- `.../animations/scenes/river_scene.dart` — water/stakes/boats CustomPainter
- `.../animations/content/bach_dang_938_tide_v1.dart` — 6-step scene content
- `dau-viet-mobile/test/learning/historical_animation_test.dart` — 21 tests
- `dau-viet-admin/src/features/lessons/builder/read-editor.test.tsx` — 4 tests
- `plans/261022-interactive-historical-animations/plan.md`
- `plans/reports/code-reviewer-261022-1757-anim01.md`

## Files modified

- `read_renderer.dart` — resolves `config.animationKey` via registry; keyed
  player above ActivityCard; unknown/missing key → plain READ; submit `{}` unchanged.
- `SimpleActivityValidators.java` (ReadValidator) — optional `animationKey`:
  non-textual → `INVALID_TYPE`; blank/>80/pattern-mismatch → `INVALID_ID`
  (`^[a-z0-9]+(_[a-z0-9]+){0,7}$`). Backend does not verify registry existence.
- `read-editor.tsx` — "Mã hoạt họa (Flutter)" input; clears→deletes key;
  preserves `text`/other config/`evidenceRefs`; readOnly disables.
- `text-renderers.tsx` (`ReadActivityView`) — honest preview line:
  "Hoạt họa Flutter: {key} — mở trên ứng dụng để chạy tương tác".
- `DraftValidatorTest.java` +5, `LearnerProjectionServiceTest.java` +1,
  `preview-renderers.test.tsx` +2, `docs/API_SPEC.md` +1 contract bullet.

## Architecture

`config.animationKey` (JSON, server-validated shape) → learner projection
pass-through → `HistoricalAnimationRegistry.resolve(key)` → typed
`HistoricalAnimationDefinition` → `HistoricalAnimationPlayer` (one
`AnimationController` + one `Timer` for auto-advance, all state local).
Scene painters expose mutable fields synced per frame; `with ChangeNotifier`
setters notify repaints (fixes the same-instance CustomPainter freeze).
Keyed `ValueKey('anim_{key}_{activityId}')` isolates state per activity.

## Bach Dang 938 sequence

6 steps: stakes prep (water 0.30) → tide rises (0.90) → boats enter (0.90,
boats 0.85) → tide falls (0.28) → boats obstructed (0.28, tilt) → strategy
explained. Prediction asks what tide-ebb changes; reveal forces low water +
highlight stakes. Disclaimer + museum source rendered every step.

## Review findings addressed

- M1: player split into `widgets/` (water control, prediction block, skipped
  scene) — file now ~265 LOC.
- M2: `_setWater` now stops in-flight controller — manual drag wins tween.
- L1: `_togglePlay` end-of-steps path rewritten without nested setState.
- L4: `SkippedScene` uses `DauVietTypography`.
- L6: admin input no longer trims per keystroke; blank-only deletes key.
- L2/L3/L5/L7: accepted as cosmetic/intentional (documented in code).

## Self-found fix

`HistoricalScenePainter` was re-instantiated per build AND fields were plain
public — same painter instance meant `RenderCustomPaint` skipped repaints.
Fixed via `with ChangeNotifier` + notifying setters + `dispose()`.
Regression test: `setters notify repaint listeners`.

## Verification (actually run)

- `./mvnw test -Dtest=DraftValidatorTest,LearnerProjectionServiceTest` — 30+23 pass
- `./mvnw test -Dtest=HiddenKeyLeakIT,HandlerSafetyTest,ItemUnlockIT` — pass
- `flutter test test/learning/historical_animation_test.dart` — 21/21
- `flutter test` (full suite) — 185/185
- `flutter analyze` — no issues; `dart format --set-exit-if-changed` — clean
- admin `npx vitest run read-editor + preview-renderers` — 16/16
- admin `tsc --noEmit` — clean; `next lint` — clean
- `git diff --check` — clean

## Not done / manual step

- No live Bạch Đằng READ lesson is seeded in backend (only Flutter mock
  data) — attach via Admin: Lesson Builder → READ activity → "Mã hoạt họa
  (Flutter)" = `bach_dang_938_tide_v1` → save/publish.
- ANIM-02/03/04 intentionally out of scope.
- No Playwright/browser E2E (per constraints); no APK built.

## Unresolved questions

- Slider-vs-tween semantics during drag resolved by stopping the tween
  (manual input wins). If product prefers "drag is preview-only", revisit.
