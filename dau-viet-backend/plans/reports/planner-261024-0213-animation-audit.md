# Animation Engine Audit — Cinematic 2.5D EPIC planning input

Date: 2026-10-24 · Planner agent · Branch: main (clean) · Last commit: `2d04386 fix`

## Scope

Audited current state of data-driven animation engine (post `82765d3` + fix-harden plan `plans/261024-0132-animation-engine-fix-harden/`). All P0/P1 done except P1-10 (Docker off → Testcontainers blocked).

## Backend (dau-viet-backend)

### Manifest contract — `manifest/AnimationManifestSchema.java`

- `CURRENT_SCHEMA_VERSION = 1`
- `RENDERER_CODES = {RIVER_TIDE, JOURNEY_MAP}`
- `OBJECT_TYPES` (10): STAKE BOAT DECOY MARKER LABEL ROUTE BACKGROUND LOCATION WATER TEXT
- `EASINGS` (5): linear, easeIn, easeOut, easeInOut, easeInOutCubic
- `EFFECTS` (7): HIGHLIGHT PULSE SHAKE FADE_IN FADE_OUT SHOW_SEQUENCE_SUMMARY REVEAL
- `INTERACTIONS` (3): WATER_LEVEL_CONTROL TAP_TO_EXPLORE PREDICTION
- `PLAYBACK_MODES` (3): AUTO STEPPED INTERACTIVE
- `ASSET_ROLES` (5): BACKGROUND OBJECT THUMBNAIL AUDIO OVERLAY — **AUDIO already whitelisted at schema level**
- `TOP_LEVEL_KEYS` (16): schemaVersion, rendererCode, rendererVersion, title, learningObjective, canvas, assets, objects, initialState, steps, interactions, narration, prediction, sourceReferences, disclaimer, river, map — **no camera/tracks/effects/audio/environment yet**
- `STATE_KEYS` per renderer — RIVER (11 keys incl. stakeVisibility/stakeHighlight), JOURNEY_MAP (7 keys)

### `manifest/AnimationManifestValidator.java` (~680 lines, 15-point check)

- Whitelist-strict: unknown top-level keys → `UNKNOWN_FIELD`; unknown state keys → `UNKNOWN_STATE_KEY`; unknown effects/interactions → `INVALID_VALUE`.
- Bounds: `MAX_MANIFEST_BYTES=256KB`, `MAX_DEPTH=24`, `MAX_STEPS=60`, `MAX_OBJECTS=200`, `MAX_ASSETS=60`.
- `schemaVersion` rule: must equal `CURRENT_SCHEMA_VERSION` OR `template.schemaVersion` — **ready for v2 bump**.
- Referential checks: stakeVisibility/stakeHighlight → `river.stakes[].id`; markerVisibility/markerHighlight/focusedLocationId → `map.locations[].id`; routeProgress → `map.routes[].id`.
- `assets[]` requires `id` (regex `[a-z0-9][a-z0-9-]{0,63}`), `assetId` (must be ACTIVE Asset UUID), `role`.
- `map.backgroundAssetId` resolves to ACTIVE asset.
- Required: `title`, `steps` non-empty, `sourceReferences` ≥1 with title, `disclaimer`.

### `application/AnimationScenePublishService.java`

- Transactional publish: pessimistic lock → validate → embed asset metadata in snapshot `assets[]` (id, assetId, role, storageKey, mimeType, sizeBytes, originalFilename, altText) → insert `animation_scene_versions` (schemaVersion/rendererCode/rendererVersion/versionNo/checksum) → record `animation_scene_asset_refs` → update `current_version_id`.
- `collectAssetRefs` picks up `manifest.assets[]` + `map.backgroundAssetId` — **audio refs will ride the same path automatically since `role` is preserved**.
- Checksum: `sha256(write(snapshot_text))` — same recipe as V15 seed.

### `domain` + `api/dto/AnimationDtos.java`

- `AnimationSceneVersion` immutable (DB trigger `trg_animation_scene_versions_immutable`).
- `SceneCreateRequest`: `templateId` @NotNull, `eventId` optional, `title` @NotBlank, `draftJson`.
- `SceneResponse` exposes `currentVersionId`, `currentVersionNo`, `rowVersion`, `rendererCode` — admin picker-compatible.
- `TemplateUpdateRequest` allows `capabilitiesJson`, `defaultConfigJson` patch — supports capability advertisement for new fields.

### Migrations

- `V14__animation_engine.sql` — full schema. Triggers for immutable versions. `chk_animation_scene_published_version` enforces `current_version_id NOT NULL` when status=PUBLISHED.
- `V15__animation_seed.sql` — 2 templates (RIVER_TIDE v1, JOURNEY_MAP v1) + 3 PUBLISHED v1 scenes with sha256 checksums. **Seed scenes use schemaVersion=1, no camera/tracks/effects/audio keys** — must keep validating unchanged.

### Asset service

- `lesson/application/AssetService.java` `ALLOWED_MIME_EXT` = `image/png|jpeg|webp` ONLY. **Audio (mp3/wav/ogg) currently rejected at upload — must extend for cinematic epic**.

## Flutter (dau-viet-mobile)

### `runtime/animation_manifest_dto.dart` (~500 lines)

- Immutable DTO; `fromJson` tolerant (ignores unknown fields — **forward-compatible with v2 by default**).
- Parses: schemaVersion, rendererCode, rendererVersion, title, learningObjective, canvasAspectRatio, steps, prediction, interactions, disclaimer, sourceReferences, transitionDuration, initialState, stakes (river), locations/routes (map), assetRefs, objects, backgroundAssetId, assetAltText.
- `toDefinition()` extension bridges to legacy `HistoricalAnimationDefinition` — painters reused.
- `AnimationObjectDto` already has `position, scale, layer, visible, shape, assetRef` — **already 80% ready for keyframed properties (rotation/opacity missing)**.
- `AnimationAssetRefDto`: `{id, assetId, role}` — sufficient for AUDIO binding.

### `runtime/animation_scene_renderer.dart` + `river_tide_renderer.dart` + `journey_map_renderer.dart` + `animation_runtime_registry.dart`

- Per-renderer `rendererCode`, `supportedRendererVersion=1`, `canRender`, `build(playbackMode)`.
- Registry is a fixed list — easy to bump `supportedRendererVersion` to 2 once v2 lands.
- `parseManifest` is fail-safe (returns null on bad payload → `read_renderer` falls back).

### `historical_animation_player.dart` (~480 lines)

- Single `AnimationController` per widget, `SceneTransition.applyFrom(painter, frozenFrom, t)` — frozen-snapshot lerp already correct.
- `_stepCurve` per-step easing, `_scheduleAdvance` AUTO mode, `_tweenPaused` resume semantics, `_selectLocation` settle-on-tap.
- `_reduceMotion` via `MediaQuery.maybeDisableAnimationsOf` — jump to `t=1`, 4s hold.
- **No second controller for camera yet** — Phase 02 will add one (or reuse master timeline; recommended single-controller design).
- `ManifestAssetLayers` wraps `CustomPaint` — extension point for camera transform + per-object visual state is already in place.

### `widgets/manifest_asset_layers.dart`

- Stacks: background image (opacity 0.45) → painter → objects by `layer`.
- Fetches via `fetchLearningAssetBytes` once per assetId at initState — already audio-byte-ready pattern.
- Auth-aware: `_authed` check → skip fetch → placeholder.
- `_positioned` uses static `o.position`/`o.scale` — **Phase 03 will consume dynamic `ObjectVisualState` here**.

### `historical_animation_definition.dart`

- `HistoricalAnimationStep`: label, narration, hint, target (`SceneTransition`), durationMs, easing — already adequate.
- `SceneTransition.applyFrom` contract is sound for v2; no breaking change needed.
- `HistoricalAnimationDefinition` includes `aspectRatio`, `playbackMode`, `hasWaterControl`, `hasLocationExplorer` — v2 needs new fields like `camera`, `tracks`, `effects` OR keep them separate from definition (recommended: separate channels via `AnimationManifestDto` directly).

### `scenes/river_scene.dart` + `scenes/historical_map_scene.dart`

- `RiverSceneState` (waterLevel, boatProgress, boatsObstructed, highlightStakes, decoyProgress, counterattackProgress, showSequenceSummary) — all lerped.
- `MapSceneState` (markerVisibility map, routeProgress map, highlighted set, focusedId) — same pattern.
- `MapLocation`/`MapRoute` already normalized 0..1 — camera focus refs can reuse these ids.

### `read_renderer.dart`

- Envelope `{manifest, sceneVersionId, versionNo, rendererCode, rendererVersion}` → `AnimationRuntimeRegistry.parseManifest` → `canRender`/`build` → `ManifestAssetLayers(HistoricalAnimationPlayer)`.
- Legacy `animationKey` fallback to `HistoricalAnimationRegistry` preserved.
- `_UnsupportedAnimationNotice` for forward-compat (old app meets new renderer).
- `playbackMode` from config — AUTO/STEPPED/INTERACTIVE already plumbed.

## Admin (dau-viet-admin)

### `features/animations/animation-types.ts`

- Mirrors backend DTOs + manifest schema. Constants: RENDERER_CODES, EASINGS, EFFECTS, INTERACTION_CODES, ASSET_ROLES (all 5), PLAYBACK_MODES.
- `AnimationManifest` interface: includes `assets`, `objects` (with `position/scale/rotation/visible/layer/assetRef/shape`), `steps` (with `effects`, `allowedInteractions`), `interactions`, `river`, `map` — **rotation already declared in `ManifestObject`**.
- `emptyManifest(rendererCode, rendererVersion)` factory — v2 seed needs `schemaVersion: 2` field.

### `scene-editor.tsx` + `use-scene-editor.ts`

- 8-section form + sticky preview column; PATCH `draftJson` with `expectedRowVersion`.
- Sections: General, Canvas, Assets, Objects, RiverStakes|JourneyMap (renderer-conditional), Timeline, Interactions, InitialState, Sources, Publish.
- `SUPPORTED_ASSET_ROLES = {BACKGROUND, OBJECT}` in `editor-sections.tsx` — **must add `AUDIO`** once backend mime whitelist extended.

### `scene-editor/scene-preview.tsx` (~360 lines)

- SVG-based preview: River (water/stakes/boats/decoy/counterattack/summary) + Map (locations/routes/markers, tap-to-explore).
- Applies merged `initialState + step.targetState`, plays back with `durationMs`, water slider for INTERACTIVE.
- **Already parity-aware**: explicit comments "preview parity với Flutter".
- Will need camera transform wrap + keyframe evaluator + effects overlays + audio badges (Phase 05).

### `scene-editor/editor-sections.tsx` (~580 lines) + `renderer-editors.tsx` (~570 lines) + `timeline-section.tsx` + `publish-section.tsx`

- `EffectsChecklist` already exists — extend for new effect types.
- `RiverStateFields` / `MapStateFields` render per-renderer state editors.
- `JourneyMapEditor` includes canvas click-to-place + route editor — pattern reusable for camera-focus visual editor.
- `PublishSection` calls `/validate` then `/publish` with rowVersion — new v2 errors flow through existing path/code/message list.

## Blockers & risks surfaced in audit

1. **Docker daemon off** → P1-10 Testcontainers ITs still blocked; continue MockMvc + unit tests.
2. **Audio mime whitelist missing** → `AssetService` rejects mp3/wav/ogg; must extend (Phase 01).
3. **Preview parity drift risk** — admin preview is SVG; Flutter is CustomPainter. New camera/keyframe math must be implemented in BOTH places; recommend a pure-TS `cinematic-eval.ts` + pure-Dart `cinematic_state.dart` kept semantically identical.
4. **`editor-sections.tsx` already ~580 lines** — new v2 sections (camera/tracks/effects/audio) MUST live in separate files to respect 200-line file-size guideline.
5. **SchemaVersion gate subtlety** — current rule accepts `schemaVersion == CURRENT OR == template.schemaVersion`. With CURRENT=2 and template=1, a v1 manifest still passes (template match). With CURRENT=2 and template=2, a v1 manifest also passes (template match). Decision: keep accepting `min(CURRENT, template.schemaVersion)` and additionally require `schemaVersion >= 2` iff V2 keys present.
6. **Object id ↔ audio assetRef namespacing** — audio uses `assetRef` → `assets[].id`, not `objects[].id`. Validator must keep these namespaces distinct.
7. **V15 scenes' `manifest.assets = []`** — no AUDIO refs present; safe baseline.
8. **Keyframe evaluator needs scene-time domain** — manifest `steps[].durationMs` is per-step TOTAL (transition + hold). `tMs` for keyframes should be scene-global; player must accumulate elapsed time across step boundaries.
9. **`AudioCueDto.stepId` resolution** — `steps[].id` is arbitrary string (e.g., "prepare", "tide-rise"); audio validator must check `stepId` ∈ `steps[].id`.
10. **`environment` semantic** — RIVER_TIDE-only ambient fields (mist/glow/waterLevel base) should be rejected on JOURNEY_MAP — `RENDERER_MISMATCH`.

## Unresolved questions (for user / implementer)

- Should `effects[]` coexist with existing step `effects[]` (HIGHLIGHT/PULSE/SHAKE/FADE_IN/FADE_OUT/SHOW_SEQUENCE_SUMMARY/REVEAL) or replace? Recommendation: keep both — step effects stay semantic flags, top-level `effects[]` are environment overlays with params. Distinct names avoid ambiguity.
- Should `camera` be per-scene (single timeline) or per-step (each step overrides)? Recommendation: `camera.initial` + `camera.steps[i]` aligned to `steps[i]` by index — simplest, deterministic.
- Audio LOOP handoff across steps — if `audio[i]` for step N is LOOP and step N+1 has no LOOP, does N's loop persist or stop? Recommendation: stop on step exit unless next step explicitly continues the same assetRef.
- Silent WAV fixture vs admin-uploaded audio for V16 seed — needs content decision; recommend bundling a tiny silence.wav fixture to keep E2E reproducible.
