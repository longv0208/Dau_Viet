# Phase 01 — Manifest schema v2 + validator

## Context

- Backend schema at `dau-viet-backend/src/main/java/com/dauviet/animation/manifest/AnimationManifestSchema.java`.
- Validator at `dau-viet-backend/src/main/java/com/dauviet/animation/manifest/AnimationManifestValidator.java`.
- V14 schema, V15 seed already shipped 3 published v1 scenes.
- `ASSET_ROLES` already includes `AUDIO` (whitelist) but `AssetService.ALLOWED_MIME_EXT` only accepts `image/png|jpeg|webp` — audio upload currently impossible.

## Overview

- Priority: P1
- Status: pending
- Add `camera`, `tracks`, `effects`, `audio`, `environment` as optional whitelisted top-level keys. Bump `CURRENT_SCHEMA_VERSION` to 2 and add version-gating: any v2 key → `schemaVersion` ≥ 2.

## Key insights

- The validator is the single gate for publish. Adding to `TOP_LEVEL_KEYS` + dedicated checks preserves whitelist semantics.
- Assets embed at publish already pins metadata — audio refs reuse the same `{id, assetId, role}` binding with `role=AUDIO`.
- schemaVersion is stored on `animation_scene_versions` — old snapshots stay at 1 forever.

## Requirements

- Backward compat: a v1 manifest (no new keys) still validates, still publishes as schemaVersion 1.
- Forward compat rule: manifest containing ANY of {camera, tracks, effects, audio, environment} must declare `schemaVersion >= 2` → else `OUTDATED_SCHEMA` error.
- New field validators emit `{path, code, message}` errors, never throw.
- Numeric bounds: camera zoom 0.5..3.0, position/opacity 0..1, rotation -360..360, volume 0..1, tMs >= 0.
- Referential integrity: `tracks[].objectId` ∈ `objects[].id`; `camera.steps[].focusObjectId` ∈ `objects[].id`; `camera.steps[].focusLocationId` ∈ `map.locations[].id`; `audio[].assetRef` ∈ `assets[].id` AND that entry's `role == "AUDIO"`; `audio[].stepId` ∈ `steps[].id`.
- `keyframes[].tMs` strictly ascending; sum of `steps[].durationMs` (default 4000 when absent) is the upper bound for `tMs`.
- `effects[].type` whitelist: `WATER_RIPPLE`, `MIST`, `GLOW`, `ROUTE_REVEAL`, `FADE_IN`, `FADE_OUT`. `params` is a bounded JSON object (depth ≤ 4).
- `environment` (RIVER_TIDE only): `waterLevel` 0..1; `mist`/`glow` 0..1 intensity.
- Reject `environment` on `JOURNEY_MAP` → `RENDERER_MISMATCH`.
- Audio mime types: extend `AssetService.ALLOWED_MIME_EXT` to include `audio/mpeg` (mp3), `audio/wav` (wav), `audio/ogg` (ogg) — audio required for cinematic epic.

## Architecture

```
AnimationManifestSchema:
  CURRENT_SCHEMA_VERSION = 2
  TOP_LEVEL_KEYS += camera, tracks, effects, audio, environment
  CAMERA_*_BOUNDS, TRACK_PROPERTIES, EFFECT_TYPES, AUDIO_CUES
  V2_KEYS = {camera, tracks, effects, audio, environment}
```

```
AnimationManifestValidator.validate(manifest, template):
  existing v1 checks (unchanged)
  + detectV2(manifest) → require schemaVersion >= 2
  + validateCamera(manifest.camera)
  + validateTracks(manifest.tracks)
  + validateEffects(manifest.effects)
  + validateAudio(manifest.audio)
  + validateEnvironment(manifest.environment)
```

## Related code files

Modify:
- `src/main/java/com/dauviet/animation/manifest/AnimationManifestSchema.java`
- `src/main/java/com/dauviet/animation/manifest/AnimationManifestValidator.java`
- `src/main/java/com/dauviet/lesson/application/AssetService.java` (mime whitelist + AUDIO)
- `src/main/java/com/dauviet/animation/application/AnimationScenePublishService.java` (already embeds `role` — confirm AUDIO role persists; no change expected)

Tests:
- `src/test/java/com/dauviet/animation/manifest/AnimationManifestValidatorTest.java` (extend)
- `src/test/java/com/dauviet/lesson/application/AssetServiceTest.java` (audio mime)

## Implementation steps

1. Add constants to `AnimationManifestSchema` (`CAMERA_ZOOM_MIN/MAX`, `TRACK_PROPERTIES`, `EFFECT_TYPES_V2`, `AUDIO_CUES`, `V2_KEYS`, `CURRENT_SCHEMA_VERSION = 2`).
2. In validator, after schemaVersion check: scan `V2_KEYS` in manifest; if any present && schemaVersion < 2 → error.
3. Implement `validateCamera` (bounds + focus refs against objects/locations).
4. Implement `validateTracks` (objectId ref, property whitelist, keyframe ordering, per-property value type).
5. Implement `validateEffects` (type whitelist + params depth bound).
6. Implement `validateAudio` (assetRef→AUDIO role, stepId ref, cue enum, volume bound).
7. Implement `validateEnvironment` (RIVER_TIDE only; numeric bounds).
8. Extend `AssetService.ALLOWED_MIME_EXT` for audio.
9. Tests: validator accepts v1 unchanged; rejects v2 keys under schemaVersion 1; each new rule has positive + negative cases.
10. `mvn -pl . test -Dtest='*Animation*,*Asset*'`.

## Todo list

- [ ] Schema constants + `CURRENT_SCHEMA_VERSION = 2`
- [ ] V2 key detection + schemaVersion gate
- [ ] Camera validator + tests
- [ ] Tracks validator + tests
- [ ] Effects validator + tests
- [ ] Audio validator + tests
- [ ] Environment validator + tests
- [ ] Audio mime whitelist + tests
- [ ] Publish snapshot embeds AUDIO refs (verify by test, no code change)

## Success criteria

- `mvn test` green for animation/lesson modules.
- V15 scenes still publish-validate clean (regression test).
- A hand-built v2 manifest with camera+tracks+effects+audio validates clean.

## Risks

- Audio bytes embed increases snapshot size — keep sizeBytes bound in `MAX_MANIFEST_BYTES`; snapshot embed already stores metadata only (not bytes) so fine.
- Old admin UI might not render new keys → Phase 05 will sync `animation-types.ts`.

## Security

- Whitelist still enforced — no executable payload; params objects bounded.
- Audio endpoint reuses existing `LearnerAssetController` auth; no new surface.
