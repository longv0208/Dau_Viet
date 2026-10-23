# Phase 04 — Flutter audio cues

## Context

- `DauVietAudioService` (`lib/core/audio/dau_viet_audio_service.dart`) already manages SFX pool + narration player + volume/mute state.
- Manifest `audio[]` parsed in Phase 02: `{stepId, assetRef, cue: ENTER|EXIT|LOOP, volume, fadeMs?}`.
- Asset bytes fetched via `fetchLearningAssetBytes` (auth required).
- Reduced-motion should not silence audio but audio is OPTIONAL — must be lifecycle-safe (no crash when muted/skipped/missing).

## Overview

- Priority: P2
- Status: pending
- Bind `audio[]` cues to step lifecycle: when step becomes active, fire ENTER cues; on step exit, fire EXIT cues; LOOP cues play for the step's duration (or until replaced). Resolve `assetRef` → `assets[]` AUDIO → bytes → audioplayers.

## Key insights

- Don't create a new audio service — reuse `DauVietAudioService` (already has `isSoundEnabled`, `isNarrationEnabled`, mute toggle, audioplayers lifecycle).
- Asset fetch must be once-per-asset, cached. Reuse `fetchLearningAssetBytes` (returns `List<int>`); `audioplayers` accepts `BytesSource`.
- LOOP semantics: `AudioPlayer.setReleaseMode(ReleaseMode.loop)`; stop when step exits or another LOOP cue takes over (only one LOOP at a time).
- Mute: respect existing `_isSoundEnabled` / `_isNarrationEnabled`. If false → don't even fetch audio bytes.
- Lifecycle: when widget disposes → stop all animation-bound players. When skipped (`_skipped` true) → stop all cues.

## Requirements

- Cues fire on step transitions, not on every frame — wire into `_applyStep` / `_goTo` / `_replay` / `_skip` / `dispose`.
- ENTER cue plays once per step entry (unless replay).
- EXIT cue plays once when leaving step (rarely used).
- LOOP cue plays while step is active; pause when learner pauses the player (when `_playing` false, LOOP pauses too — but resume on play).
- `volume` 0..1 multiplied into player volume; `fadeMs` optional fade-in/out.
- If `assetRef` doesn't resolve to an `assets[]` entry with `role=AUDIO`, ignore silently (validator already rejects, but defensive).
- Missing auth / failed fetch → cue is no-op, animation still plays.
- Mute toggle (`_isSoundEnabled=false`) → cues do not fetch/play.

## Architecture

```
AnimationAudioController (ChangeNotifier, owned by player state)
  attach(DauVietAudioService, manifest, fetcher)
  onStepEnter(stepIndex)
  onStepExit(stepIndex)
  onPause() / onResume()
  dispose()

AudioCueDto (parsed in manifest)
  stepId, assetRef, cue, volume, fadeMs

ManifestAssetLayers (or Player build)
  creates AnimationAudioController, wires callbacks into player lifecycle
```

Create:
- `dau-viet-mobile/lib/features/learning/presentation/animations/runtime/animation_audio_controller.dart`

Modify:
- `dau-viet-mobile/lib/features/learning/presentation/animations/historical_animation_player.dart` — wire audio controller into `_applyStep`, `_goTo`, `_replay`, `_skip`, `dispose`, `_togglePlay`.
- `dau-viet-mobile/lib/features/learning/presentation/animations/runtime/animation_manifest_dto.dart` — already parses `audio[]` in Phase 02; ensure `AudioCueDto` exposes `assetId` resolved via `assets[]`.

Tests:
- `dau-viet-mobile/test/features/learning/presentation/animations/runtime/animation_audio_controller_test.dart` — with stubbed audio service.

## Implementation steps

1. `AudioCueDto` fields + parser confirmed.
2. `AnimationAudioController`: holds `Map<String, AudioPlayer>` by assetRef; `onStepEnter` resolves cues matching stepId, fetches bytes once (cache by assetId), plays with volume+fade.
3. LOOP cue handling: single `_loopPlayer`; stop on exit/pause; resume on play.
4. Player lifecycle wiring: `_applyStep` → `onStepEnter(idx)`; `_goTo`/`_replay`/`_skip` → `onStepExit(prev)` then `onStepEnter(new)`; `dispose` → `controller.dispose()`.
5. Mute check: skip fetch+play when `DauVietAudioService.instance.isSoundEnabled == false`.
6. Reduced-motion: audio still plays (decoration, not motion).
7. Tests: cue mapping, cache reuse, lifecycle cleanup, mute path, missing-asset path.

## Todo list

- [ ] `AnimationAudioController` with attach/lifecycle methods
- [ ] Player wiring (applyStep/goTo/replay/skip/dispose/togglePlay)
- [ ] Byte cache per assetId
- [ ] LOOP pause/resume semantics
- [ ] Mute + missing-auth + missing-asset safe paths
- [ ] Widget/unit tests

## Success criteria

- ENTER cue plays exactly once per step entry in widget test with stubbed audio.
- LOOP cue pauses when learner pauses the animation; resumes on play.
- Dispose during playback → no leak, no crash.
- Muted session → zero network/audio calls.
- Existing 278 tests still green.

## Risks

- audioplayers on web/desktop edge cases — tests run on host platform; add `isTestEnvironment` short-circuit (already in `DauVietAudioService`).
- Audio fetch on every step enter → mitigate with per-asset byte cache.

## Security

- Reuses authenticated `fetchLearningAssetBytes`; no new endpoint.
