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
- [x] `docs/API_SPEC.md` v2 schema section
- [x] `docs/DATABASE_DESIGN.md` V16 entry
- [x] `docs/LEARNING_ENGINE_DESIGN.md` renderer features list
- [x] `docs/development-roadmap.md` + `docs/project-changelog.md` — N/A: các
      file này không tồn tại trong repo (chỉ có PROJECT_OVERVIEW/TECH_STACK/
      CODING_RULES/API_SPEC/DATABASE_DESIGN/LEARNING_ENGINE_DESIGN đã cập nhật);
      bỏ theo YAGNI thay vì tạo file mới.
- [x] Manual admin smoke — thay bằng code-path trace + gates tự động:
      `SnapshotBuilder.embedAnimationScenes` pin snapshot vào
      `config.animationManifest` (kèm asset metadata + checksum) → mobile
      `ReadRenderer` resolve renderer + `canRender` + `ManifestAssetLayers`,
      fallback `_UnsupportedAnimationNotice`; admin `next build`/lint/vitest
      158 tests xanh; Playwright bị cấm theo task constraint.

## Final hardening (post-§1-§13 audit)

- [x] §2 — `ManifestAssetLayers` moved INSIDE `AspectRatio` canvas (markers
      stay inside camera transform; controls/narration stay outside).
- [x] §3 — `suppressBaseBackground` on `HistoricalScenePainter`; v1 painter
      keeps procedural fallback; procedural glyphs render objects lacking
      `assetRef` (BOAT/DECOY/STAKE/MARKER/LABEL/LOCATION/WATER/TEXT).
- [x] §4 — boat-decoy tracks produce visible motion via procedural glyph.
- [x] §5 — controller.duration = step.durationMs; `camera.steps[].easing`
      whitelisted → overrides step easing on camera tween (Dart + TS).
- [x] §6 — admin preview parity: real-time rAF playback, correct CSS
      camera transform `translate(center) scale(zoom) translate(-center)`
      (not `transformOrigin`), procedural glyphs for unsourced objects,
      `frameAt` handles rawProgress + easedT matching Dart evaluator.
- [x] §7 — `AnimationAudioController`: generation token aborts pending
      `fetchBytes` on step switch/skip/dispose; `fadeMs` implemented for
      LOOP (fade-in on start, fade-out on step exit).
- [x] §8 — `AnimationScenePublishService` records manifest's actual
      `schemaVersion` (v1→1, v2→2), not `CURRENT_SCHEMA_VERSION`; IT test
      `AnimationScenePublishIT` covers v1/v2/missing-field/422 cases.
- [x] §9 — `unsupportedManifest` covers renderer-missing + canRender-false;
      no silent animationKey fallback.
- [x] §10 — AUTO advance hold floor = transitionDuration + max(2.5s,
      narration.length × 14ms) clamped ≤ 12s — long narration not
      truncated by short durationMs.

## Post-review hardening (code-reviewer round 2)

- [x] IT `publishMissingSchemaVersionField_returns422` — validator
      contract (missing schemaVersion → 422, không phải silent v1).
- [x] Admin camera CSS `scale(z) translate(O−C)` — đúng parity
      Flutter `O + z·(p−C)` (trước `translate(d)·scale(z)` lệch d·(1−z)).
- [x] AUTO-advance `_applyStep(previousIndex: prev)` — EXIT cue +
      LOOP fade-out fire đúng khi autoplay.
- [x] `hasTween = step.target != null || _hasCinematic` — step
      tracks/effects-only vẫn forward controller.
- [x] `_tweenFrom = null` khi `step.target == null` trên cinematic-only
      — tránh stale-lerp "rewind".
- [x] `_startLoop` generation-check sau mỗi await + `_loopPendingBytes`
      cho paused-LOOP resume (play thay vì resume no-op).
- [x] `_rampVolume` tick sàn 16ms; `_label` glyph `?` cho cả
      TEXT/LABEL.

Open (ghi nhận, không block): EnvironmentOverlay trong camera transform
(scene-space hiện tại — cần product confirm nếu muốn screen-space);
admin preview object width hardcode 640px; chưa có test cho §10
hold-floor và §7 generation-abort (đề xuất follow-up).

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
