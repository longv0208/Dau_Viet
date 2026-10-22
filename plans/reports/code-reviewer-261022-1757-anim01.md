# ANIM-01 Code Review — Interactive Historical Animations

## Scope

- Plan: `plans/261022-interactive-historical-animations/plan.md`
- New: 6 Flutter files under `dau-viet-mobile/lib/features/learning/presentation/animations/`
  + test (`historical_animation_test.dart`), 1 admin test (`read-editor.test.tsx`)
- Modified: `read_renderer.dart`, `SimpleActivityValidators.java`, `DraftValidatorTest`,
  `LearnerProjectionServiceTest`, `read-editor.tsx`, `text-renderers.tsx`,
  `preview-renderers.test.tsx`
- LOC: ~1500 (Flutter ~1100, admin ~120, backend ~80)
- Test evidence (claimed): 20 Flutter widget tests, 30+23 backend, 16 admin vitest,
  full flutter suite 184 green, analyze clean, tsc+eslint clean. Spot-verified
  test bodies — coverage matches claims.

## Overall Assessment

Solid, scoped implementation honoring the "presentation-only" contract. Engine
is generic (no Bach Dang branches in shared code), all scene data lives in
`bachDang938TideV1`. Painter repaint is correctly wired via
`with ChangeNotifier` + setter-driven `notifyListeners` (avoids the classic
"same painter instance → no repaint" trap — see comment in
`historical_animation_definition.dart:61-63`, correct fix). Dispose is safe.
Registry → null on unknown key preserves READ fallback. Backend validates
shape only, never registry membership — correct per spec.

No critical or high defects found. One code-quality violation (file size)
and a handful of low-impact UX/consistency warts.

## Critical Issues

None.

## High Priority

None.

## Medium Priority

### M1 — `historical_animation_player.dart` = 607 LOC (project limit 200)

`development-rules.md` caps code files at 200 lines. Player currently embeds
player, `_WaterLevelControl`, `_PredictionBlock`, `_PredictionOption`,
`_SkippedScene` in one file. Suggested split:

- `historical_animation_player.dart` — widget + state only (~200 LOC)
- `widgets/water_level_control.dart` — `_WaterLevelControl`
- `widgets/prediction_block.dart` — `_PredictionBlock` + `_PredictionOption`
- `widgets/skipped_scene.dart` — `_SkippedScene`

Tests import the public widgets via `HistoricalAnimationPlayer` only, so
split is non-breaking.

`river_scene.dart` (219 LOC) and `historical_animation_test.dart` (335 LOC)
marginally exceed but tolerable — painter is a cohesive unit and test files
are conventionally exempt.

### M2 — `_setWater` does not stop in-flight `_controller`

`historical_animation_player.dart:183-191`. During a step transition
(`_controller.forward()` running), if the user drags the slider:
`_waterFrom = _waterLevel` becomes the dragged value, but `_onTick` continues
lerping toward `step.targetWaterLevel`. Result: the user's drag "fights" the
remaining tween — position is pulled toward the step target until
`_controller` completes.

Not a crash; arguably intended (step semantics preserved). If the desired UX
is "slider wins", add `_controller.stop()` inside `_setWater`. If intended,
leave as is — worth one-line comment to document choice.

## Low Priority

### L1 — Nested `setState` when `_togglePlay` invokes `_replay`

`historical_animation_player.dart:136-146`. `_togglePlay` runs `setState`,
inside it calls `_replay()` which calls `setState` again — Flutter tolerates
(inner is no-op) but is dead code. Move `_replay()` outside the outer
`setState` for clarity.

### L2 — `key.isBlank()` redundant in `ReadValidator`

`SimpleActivityValidators.java:62-65`. The regex `[a-z0-9]+(_[a-z0-9]+){0,7}`
already rejects blank strings, so `key.isBlank()` is unreachable as a
*distinct* rejection path. Harmless; can drop or keep for readability —
no action needed.

### L3 — `_PredictionOption` visual conflict when wrong choice revealed

`historical_animation_player.dart:467-473, 559-601`. When `revealed=true` and
user picked wrong: the chosen option keeps `border=riverBlue` (selected) AND
gets `dimmed=true` (grey text). Two conflicting signals on one widget.
Consider dimming only unchosen wrong options, or switching selected-chosen
wrong to a warning border color. Cosmetic.

### L4 — `_SkippedScene` uses inline `TextStyle` instead of `DauVietTypography`

`historical_animation_player.dart:342-347`. Inconsistent with rest of file
which uses `DauVietTypography.bodySmall/bodyMedium`. Trivial.

### L5 — `_syncPainter()` called inside `build()`

`historical_animation_player.dart:217`. All painter state is already pushed
by every mutating path via `_syncPainter` inside `setState`. The build-time
call is a defensive no-op. Can drop — or keep as belt-and-suspenders; no
impact.

### L6 — `ReadEditor` input `.trim()` strips in-progress whitespace

`read-editor.tsx:46`. `e.target.value.trim()` on every keystroke means typing
a trailing space (preparing another word) is immediately stripped. Also
prevents typing `_` between segments mid-edit. Pattern enforcement is
server-side anyway; consider validating on blur or removing `.trim()` and
relying on the backend INVALID_ID response. Minor UX.

### L7 — Slider drag during auto-play silently stops playback

`_setWater` sets `_playing = false` without user-facing cue. By design per
comment ("thao tác tay → không auto-advance"), but a subtle state change
worth a tooltip or snackbar if real users get confused. Optional.

## Edge Cases Verified

- Unknown/missing `animationKey` → `Registry.resolve` returns null → plain
  READ renders. Covered by tests.
- Activity switch disposes player via `ValueKey('anim_${key}_${id}')`.
- Explicit `null` in JSON config handled via `anim.isNull()` in validator.
- `LEARNER_HIDDEN_KEYS` leaf-name match — `animationKey` doesn't collide
  with `"key"` (exact-match set, not substring). Test
  `read_animationKey_survivesProjection` verifies.
- Prediction reveal is local-only; no submit path reached. Test
  `prediction feedback is local` asserts `sent == null`.
- Timer race on dispose: `_advanceTimer?.cancel()` in `dispose` + `mounted`
  check inside callback — double-safe.
- `CustomPainter` repaint: `with ChangeNotifier` correctly overrides
  `Listenable` contract — `RenderCustomPaint.addListener` hits
  ChangeNotifier's listeners, `notifyListeners()` triggers `markNeedsPaint`.
- Reduced-motion: `disableAnimations` → `_applyStep` skips `forward()`, sets
  target values directly. Auto-advance uses 4s read delay. Covered.
- Two players independent — tested via two `ValueKey` instances.
- Backend rejects: uppercase, space, dash, dot, `..`, `__`, >80 chars,
  non-textual. Accepts: missing, valid key.

## Spec Compliance Check

| Requirement | Status |
|---|---|
| Optional `config.animationKey` on READ, typed registry | Pass |
| 6-step Bach Dang sequence with specified narration arc | Pass |
| Water-level slider 0..1 normalized + `Nước dâng`/`Nước rút` presets | Pass |
| Ungraded prediction, never POSTed | Pass (verified via test) |
| Disclaimer + source rendered | Pass |
| Play/pause/prev/next/replay/skip + reduced-motion + dispose safe | Pass |
| No new ActivityType / no game engine / no event-specific branches | Pass |
| Backend shape-checks key only (no registry existence check) | Pass |
| Admin editor preserves other config keys; preview honest | Pass |
| Backend authoritative; presentation never POSTs; no answer keys leaked | Pass |

## Positive Observations

- **Correct CustomPainter wiring** — `with ChangeNotifier` + setter-driven
  `notifyListeners` is the right fix for the same-instance repaint trap.
  The comment at `historical_animation_definition.dart:61-63` documents the
  exact failure mode — rare and useful.
- Registry pattern keeps event logic out of generic renderer — clean,
  versioned (`_v1` suffix convention encouraged by validator hint).
- Tests cover edge cases honestly: unknown key fallback, two-player state
  isolation, dispose-during-play, reduced-motion path, small-screen layout.
- Backend `INVALID_ID` vs `INVALID_TYPE` split gives admins actionable errors.
- Prediction uses `explainedOptionIndex` (not `correctIndex`) — accurate
  framing for non-graded exploratory UX.
- Admin preview is honest about Flutter-only scope — no false claim of
  interactivity.
- Vietnamese semantic labels throughout — good a11y.

## Recommended Actions

1. (M1) Split `historical_animation_player.dart` into 3-4 files under
   `animations/widgets/` to respect the 200-LOC rule.
2. (M2) Decide slider-vs-tween semantics; add `_controller.stop()` in
   `_setWater` OR comment why tween wins.
3. (L1, L4, L5) Cosmetic cleanups — nested setState, typography, redundant
   `_syncPainter`.
4. (L3, L6) UX polish — dim rule clarity, `.trim()` on edit.
5. (L7) Optional UX cue on slider-kills-autoplay.

No blocking issues. Ship-ready pending file-split decision.

## Metrics

- Type coverage: 100% (Dart typed, TS typed, Java typed)
- Test coverage (new code): Player behavior ~85% via widget tests;
  validator paths 100% via parametrized test; admin editor paths 100%.
- Linting: clean per user claim; spot-checked no analyzer-suppression hacks.

## Unresolved Questions

- Intended UX for slider drag during an active tween: "drag wins" or
  "tween wins"? Current behavior is tween-continues-from-dragged-position
  which is a defensible middle ground but may feel unresponsive.
- Whether `historical_animation_player.dart` size violation warrants
  immediate refactor or can wait until ANIM-02 lands (when a second scene
  will force the split anyway).
