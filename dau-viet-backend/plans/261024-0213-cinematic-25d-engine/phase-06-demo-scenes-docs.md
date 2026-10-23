# Phase 06 — Demo scenes + reduced-motion + docs

## Context

- V15 seed created 3 v1 scenes: `bach_dang_938` (RIVER_TIDE), `hai_ba_trung_40` (JOURNEY_MAP), `ly_thai_to_1010` (JOURNEY_MAP).
- Published snapshots are immutable — to "upgrade" a scene, we must either (a) create new v2 drafts as new scenes, OR (b) publish new versions of existing scenes via the admin flow.
- Reduced-motion path already exists (`_reduceMotion` in player); must extend to camera/tracks/effects.

## Overview

- Priority: P2
- Status: pending
- Deliver 3 upgraded demo scenes exercising camera+tracks+effects+audio; ensure reduced-motion path; update docs.

## Key insights

- Do NOT mutate V15 migration (immutable). Add a new migration `V16__animation_cinematic_demos.sql` that either (a) inserts new v2 scenes alongside, or (b) updates `draft_json` of existing DRAFT scenes + publishes v2 versions. Prefer (a) — safer, leaves v1 scenes intact.
- Audio: needs at least one AUDIO asset seeded — requires actual audio file uploaded via AssetService; seed data can't fabricate bytes. **Decision**: seed audio REFERENCES in manifests but mark audio cues optional; document that admins must upload real audio via admin UI. Alternatively seed a tiny silent WAV fixture.
- Reduced-motion semantics for camera: jump to step's `camera.target` instantly (no tween). Same for keyframes — evaluate at `tMs = ∞` (final value).

## Requirements

- `V16__animation_cinematic_demos.sql`: 3 new scenes seeded as PUBLISHED schemaVersion=2:
  1. `bach_dang_938_cinematic` — RIVER_TIDE v2, camera zooms into stake field on "Nước rút" step; track animates a decoy boat OBJECT; mist ambient; audio LOOP (river ambience).
  2. `hai_ba_trung_40_cinematic` — JOURNEY_MAP v2, camera pans between locations per step; route reveal effect; audio ENTER on each step.
  3. `ly_thai_to_1010_cinematic` — JOURNEY_MAP v2, camera zoom-out on final step; fade-in effect on title; audio ENTER.
- Each demo manifest must pass `AnimationManifestValidator` cleanly (positive test in validator suite).
- Reduced-motion: write a widget test that asserts for each demo manifest, `MediaQuery.disableAnimations=true` produces the final state without tween.
- Docs updates: `docs/API_SPEC.md` (manifest schema v2 section), `docs/DATABASE_DESIGN.md` (V16 migration), `docs/LEARNING_ENGINE_DESIGN.md` (animation renderers list), `docs/development-roadmap.md`, `docs/project-changelog.md`.

## Architecture

```
V16__animation_cinematic_demos.sql:
  INSERT animation_scenes (3 new rows, schemaVersion=2 manifests as draft_json)
  INSERT animation_scene_versions (snapshot_json = manifest + embedded assets)
  UPDATE animation_scenes SET current_version_id = ..., status = 'PUBLISHED'
  (checksum = encode(digest(snapshot_text,'sha256'),'hex') same as V15)
```

Modify:
- `dau-viet-backend/src/main/resources/db/migration/V16__animation_cinematic_demos.sql` (new)
- `dau-viet-mobile/lib/features/learning/presentation/animations/historical_animation_player.dart` — if reduced-motion handling needs extension to camera/tracks/effects (already covered in Phase 02/03 — verify here).
- `docs/API_SPEC.md`, `docs/DATABASE_DESIGN.md`, `docs/LEARNING_ENGINE_DESIGN.md`
- `docs/development-roadmap.md`, `docs/project-changelog.md`

Tests:
- `dau-viet-backend/src/test/java/com/dauviet/animation/manifest/AnimationManifestValidatorTest.java` — fixture-driven positive tests for each demo manifest.
- `dau-viet-mobile/test/features/learning/presentation/animations/historical_animation_player_test.dart` — reduced-motion path.

## Implementation steps

1. Author 3 v2 manifests as JSON (start from V15 scenes, add camera/tracks/effects/audio).
2. Validate via `AnimationManifestValidator` unit test before writing migration (prevents broken seed).
3. Write `V16__animation_cinematic_demos.sql` following V15 recipe (DO block, sha256 checksum, insert versions + update scenes).
4. Widget test: each demo manifest loads + plays; reduced-motion asserts final state.
5. Update docs files listed above.
6. Manual smoke: build admin, open demo scenes in SceneEditor, preview, publish a draft copy.

## Todo list

- [x] 3 v2 manifests authored + validator-positive tests
- [x] `V16__animation_cinematic_demos.sql` migration
- [x] Reduced-motion widget tests (camera jump + track final + effect end-state)
- [ ] `docs/API_SPEC.md` v2 schema section
- [ ] `docs/DATABASE_DESIGN.md` V16 entry
- [ ] `docs/LEARNING_ENGINE_DESIGN.md` renderer features list
- [ ] `docs/development-roadmap.md` + `docs/project-changelog.md` updates
- [ ] Manual admin smoke (documented in tester report)

## Success criteria

- Flyway applies V16 cleanly (schema_version table shows V16).
- 3 new scenes visible + PUBLISHED in admin library.
- `flutter test` includes a widget test per demo showing camera pan/zoom + keyframe + effect applied.
- Reduced-motion widget test: no `AnimationController.forward()` fired; final states correct.
- Docs files updated; each AC mapped to a check.

## Risks

- Audio asset seeding — no real audio file in repo → either seed a silent WAV fixture at `dau-viet-backend/src/main/resources/seed-assets/silence.wav` + V16 inserts an `assets` row + storage file copy, OR document that audio cues reference admin-uploaded assets. Choose first for reproducibility.
- Snapshot size — camera+tracks add ~2-5KB per manifest, well under `MAX_MANIFEST_BYTES`.

## Security

- Same whitelisted schema; checksum still enforced; immutable trigger still applies.
