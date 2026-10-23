# Phase 2 — Snapshot Integration & Flutter Runtime

## Context Links

- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/validators/SimpleActivityValidators.java` — `ReadValidator` (animationKey validation at line 36-68)
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/SnapshotBuilder.java` — `collectAssetIds`, `build`, `embedAssets`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LessonPublishService.java` — publish flow
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LearnerProjectionService.java` — learner-safe projection
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/DraftSchema.java` — `LEARNER_HIDDEN_KEYS`, `TOP_LEVEL_KEYS`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/ValidationContext.java` — context record for validators
- `dau-viet-mobile/lib/features/learning/presentation/animations/historical_animation_registry.dart` — legacy registry
- `dau-viet-mobile/lib/features/learning/presentation/animations/historical_animation_definition.dart` — `HistoricalAnimationDefinition`, `SceneTransition`, `HistoricalScenePainter`
- `dau-viet-mobile/lib/features/learning/presentation/animations/historical_animation_player.dart` — player widget
- `dau-viet-mobile/lib/features/learning/presentation/animations/scenes/river_scene.dart` — `RiverScenePainter`, `RiverSceneState`
- `dau-viet-mobile/lib/features/learning/presentation/animations/scenes/historical_map_scene.dart` — `MapScenePainter`, `MapSceneState`, `MapLocation`, `MapRoute`
- `dau-viet-mobile/lib/features/learning/presentation/renderers/read_renderer.dart` — READ renderer (animationKey resolution at line 65-67)
- `dau-viet-mobile/lib/features/learning/presentation/animations/widgets/` — prediction_block, water_level_control, map_marker_overlay, location_info_panel, historical_animation_controls, skipped_scene

## Overview

- **Priority:** P1 (depends on Phase 1)
- **Status:** in-progress — backend done; Flutter runtime pending
- **Effort:** 4h

**Backend state (already implemented):** `ValidationContext` extended with `validSceneVersionIds`/`publishedSceneIds` + `sceneVersionUsable`/`sceneHasPublishedVersion`; `ReadValidator.validateAnimationRef` handles `animationSceneId`/`animationSceneVersionId`/`playbackMode` (whitelist AUTO/STEPPED/INTERACTIVE — NOTE: plan spec said `NARRATED`, impl uses `STEPPED`; confirm intent), mutual exclusion with `animationKey`, publish-time existence checks; `SnapshotBuilder.embedAnimationScenes` resolves versionId-or-sceneId → embeds `config.animationManifest.{manifest,sceneVersionId,versionNo,rendererCode,rendererVersion}` + pins manifest assets into `assets[]`. Field name in snapshot is `animationManifest` (NOT `animationScene` as the original plan spec said) — Flutter must read `config.animationManifest`.

**Remaining work:** entire Flutter runtime track (manifest DTO, registry, two renderers, playback controller, asset resolver, read_renderer integration).

Two tracks: (a) backend — extend draft validation + snapshot embedding so READ activities can reference animation scene versions; (b) Flutter — build the manifest DTO layer, renderer registry, two renderers (RIVER_TIDE, JOURNEY_MAP), playback controller, and integration into `read_renderer.dart`.

## Key Insights

- `SnapshotBuilder.collectAssetIds()` already scans `config.imageAssetId` — extend to also scan `config.animationSceneVersionId` → look up the scene version's manifest → collect `manifest.assets[].assetId`.
- `ReadValidator` currently only validates `config.animationKey` pattern. New fields `animationSceneId`/`animationSceneVersionId`/`playbackMode` need the same treatment: optional, well-formed, publish-time existence check via `ValidationContext`-style lookups.
- `LearnerProjectionService` strips `LEARNER_HIDDEN_KEYS` recursively — animation manifest fields are NOT hidden (learner needs them). But `draft_json` internals on the scene are admin-only; only the published `snapshot_json` manifest gets embedded.
- `HistoricalAnimationPlayer` takes `HistoricalAnimationDefinition` (compiled Dart). New runtime takes `AnimationManifestDto` + renderer — same player shell, different data source.
- Legacy `animationKey` path must remain functional for existing published snapshots.

## Requirements

### Functional

1. `ReadValidator` accepts `config.animationSceneId` (UUID), `animationSceneVersionId` (UUID), `playbackMode` (enum string: `AUTO`, `STEPPED`, `INTERACTIVE` — matches implemented whitelist in `AnimationManifestSchema.PLAYBACK_MODES` and `SimpleActivityValidators.ReadValidator.PLAYBACK_MODES`) — all optional; `animationKey` is mutually exclusive with the scene pair.
2. `SnapshotBuilder` resolves `animationSceneVersionId` (or `animationSceneId` → latest version) → embeds the immutable `snapshot_json` manifest into the lesson snapshot under `config.animationManifest.{manifest,sceneVersionId,versionNo,rendererCode,rendererVersion}`; collects `manifest.assets[].assetId` + `manifest.map.backgroundAssetId` into snapshot `assets[]`.
3. `LessonPublishService` (via `PublishReadinessEvaluator`) returns 422 when `animationSceneVersionId` references a non-existent/non-published version.
4. `LearnerProjectionService` keeps `animationManifest` in learner projection but strips any admin-only fields.
5. Flutter `AnimationManifestDto` parses manifest JSON from snapshot `config.animationManifest.manifest`.
6. `AnimationRuntimeRegistry` maps `rendererCode` → `AnimationSceneRenderer` instance — keyed by renderer code only, never by eventId/lessonId.
7. `RiverTideRenderer` builds `RiverScenePainter` + `RiverSceneState[]` from manifest `objects[]`, `initialState`, `steps[]`.
8. `JourneyMapRenderer` builds `MapScenePainter` + `MapSceneState[]` from manifest `objects[]`, `initialState`, `steps[]`.
9. `AnimationAssetResolver` resolves `assetId` → URL from `snapshot.assets[]` (embedded in lesson snapshot).
10. `AnimationPlaybackController` wraps `AnimationController` + step navigation: play/pause/next/prev/replay/skip, deterministic seek, reduced motion support, dispose.
11. Fallback: `rendererCode` not in registry → render text-only READ (no crash). Legacy `animationKey` → `HistoricalAnimationRegistry` → still works.

### Non-functional

- No per-frame network calls during playback.
- Manifest parse errors → render fallback (not crash).
- Deterministic seek: given step index, painter state = lerp(from_state, to_state, t) — same as existing player.

## Architecture

### Backend Changes

```
ReadValidator (SimpleActivityValidators.java)
  └── add checks: animationSceneId UUID format, animationSceneVersionId UUID format,
      playbackMode enum, publish-time: scene version exists & status=PUBLISHED

ValidationContext
  └── add: Set<UUID> publishedSceneVersionIds (resolved by caller)

PublishReadinessEvaluator / DraftValidator
  └── resolve animationSceneVersionIds from all READ activities → add to ValidationContext

SnapshotBuilder
  └── collectAssetIds: extend to scan animationSceneVersionId → manifest.assets[].assetId
  └── build: embed animationScene.manifest into activity config when animationSceneVersionId present

LearnerProjectionService
  └── no code change needed IF manifest fields aren't in LEARNER_HIDDEN_KEYS
      (verify: manifest fields like "objects","steps","canvas" are NOT hidden — they're
       inside config.animationScene.manifest which is a nested object, not a hidden key)
```

### Flutter Runtime

```
lib/features/learning/presentation/animations/runtime/
├── animation_manifest_dto.dart        # Manifest + Step + Object + AssetRef DTOs
├── animation_runtime_registry.dart    # rendererCode → renderer map
├── animation_scene_renderer.dart      # abstract: buildPainter, buildStates, buildDefinition
├── river_tide_renderer.dart           # RIVER_TIDE implementation
├── journey_map_renderer.dart          # JOURNEY_MAP implementation
├── animation_asset_resolver.dart      # assetId → URL from snapshot assets[]
└── animation_playback_controller.dart # play/pause/seek/replay/skip + reduced motion

lib/features/learning/presentation/renderers/read_renderer.dart
  └── modified: resolve animationSceneId → manifest → registry → player
```

## Related Code Files

### Create

| File | Purpose |
|------|---------|
| `dau-viet-mobile/lib/features/learning/presentation/animations/runtime/animation_manifest_dto.dart` | Parse manifest JSON → typed DTOs |
| `dau-viet-mobile/lib/features/learning/presentation/animations/runtime/animation_runtime_registry.dart` | rendererCode → renderer |
| `dau-viet-mobile/lib/features/learning/presentation/animations/runtime/animation_scene_renderer.dart` | Abstract renderer interface |
| `dau-viet-mobile/lib/features/learning/presentation/animations/runtime/river_tide_renderer.dart` | RIVER_TIDE renderer |
| `dau-viet-mobile/lib/features/learning/presentation/animations/runtime/journey_map_renderer.dart` | JOURNEY_MAP renderer |
| `dau-viet-mobile/lib/features/learning/presentation/animations/runtime/animation_asset_resolver.dart` | assetId → resolved URL |
| `dau-viet-mobile/lib/features/learning/presentation/animations/runtime/animation_playback_controller.dart` | Playback state machine |
| `dau-viet-mobile/test/features/learning/presentation/animations/runtime/animation_manifest_dto_test.dart` | DTO parse tests |
| `dau-viet-mobile/test/features/learning/presentation/animations/runtime/river_tide_renderer_test.dart` | Renderer tests |
| `dau-viet-mobile/test/features/learning/presentation/animations/runtime/journey_map_renderer_test.dart` | Renderer tests |
| `dau-viet-mobile/test/features/learning/presentation/animations/runtime/animation_playback_controller_test.dart` | Controller tests |

### Modify

| File | Change |
|------|--------|
| `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/validators/SimpleActivityValidators.java` | `ReadValidator`: add `animationSceneId`, `animationSceneVersionId`, `playbackMode` validation |
| `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/ValidationContext.java` | Add `publishedSceneVersionIds` field |
| `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/DraftValidator.java` | Resolve scene version ids → add to ValidationContext |
| `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/SnapshotBuilder.java` | `collectAssetIds` extend; `build` embed manifest |
| `dau-viet-backend/src/main/java/com/dauviet/lesson/application/PublishReadinessEvaluator.java` | Resolve scene version ids for publish-level validation |
| `dau-viet-mobile/lib/features/learning/presentation/renderers/read_renderer.dart` | Add manifest path: `config.animationScene` → runtime registry → player |

## Implementation Steps

### Step 1: Backend — ValidationContext extension

Add `publishedSceneVersionIds` (Set\<UUID\>) to `ValidationContext` record. Callers (`DraftValidator`, `PublishReadinessEvaluator`) resolve these from the `animation_scene_versions` table — specifically: query all `animationSceneVersionId` values found in READ activity configs, check each exists and has `status='PUBLISHED'` on the parent scene.

### Step 2: Backend — ReadValidator extension

In `SimpleActivityValidators.ReadValidator.validate()`:

```java
JsonNode sceneId = config.get("animationSceneId");
JsonNode versionId = config.get("animationSceneVersionId");
JsonNode mode = config.get("playbackMode");

if (versionId != null && !versionId.isNull()) {
    if (!versionId.isTextual() || !isUuid(versionId.asText())) {
        errors.add(new FieldError(path + ".config.animationSceneVersionId",
            "INVALID_TYPE", "animationSceneVersionId must be a UUID string"));
    }
    if (sceneId == null || sceneId.isNull()) {
        errors.add(new FieldError(path + ".config.animationSceneId",
            "MISSING_FIELD", "animationSceneId required when animationSceneVersionId is set"));
    }
    if (ctx.isPublish() && !ctx.sceneVersionUsable(versionId.asText())) {
        errors.add(new FieldError(path + ".config.animationSceneVersionId",
            "SCENE_VERSION_NOT_FOUND", "scene version not found or not published"));
    }
}
if (mode != null && !mode.isNull() && !PLAYBACK_MODES.contains(mode.asText())) {
    errors.add(new FieldError(path + ".config.playbackMode",
        "INVALID_VALUE", "playbackMode must be one of " + PLAYBACK_MODES));
}
// PLAYBACK_MODES = {"AUTO","STEPPED","INTERACTIVE"} — per AnimationManifestSchema
```

Keep existing `animationKey` validation untouched — both paths coexist.

### Step 3: Backend — DraftValidator/PublishReadinessEvaluator scene resolution

In `DraftValidator.validate()`: after collecting all activity configs, scan for `config.animationSceneVersionId` textual values → query `animation_scene_versions` for existence + parent scene `status='PUBLISHED'` → populate `ValidationContext.publishedSceneVersionIds`.

### Step 4: Backend — SnapshotBuilder manifest embedding

In `SnapshotBuilder.build()`:

```java
// After setting stages/completion, scan activities for animationSceneVersionId
JsonNode stages = draft.path("stages");
for (JsonNode stage : stages) {
    for (JsonNode act : stage.path("activities")) {
        JsonNode config = act.path("config");
        JsonNode versionIdNode = config.get("animationSceneVersionId");
        if (versionIdNode != null && versionIdNode.isTextual()) {
            UUID versionId = UUID.fromString(versionIdNode.asText());
            AnimationSceneVersion sv = sceneVersions.findById(versionId).orElse(null);
            if (sv != null) {
                ObjectNode animScene = ((ObjectNode) config).putObject("animationScene");
                animScene.put("sceneId", sv.getSceneId().toString());
                animScene.put("versionId", sv.getId().toString());
                animScene.put("rendererCode", sv.getRendererCode());
                animScene.put("rendererVersion", sv.getRendererVersion());
                animScene.set("manifest", parse(sv.getSnapshotJson()));
                // Note: keep animationSceneVersionId in config for reference
            }
        }
    }
}
```

Extend `collectAssetIds()` to also collect `manifest.assets[].assetId` from embedded manifests.

### Step 5: Flutter — AnimationManifestDto

```dart
class AnimationManifestDto {
  final int schemaVersion;
  final String rendererCode;
  final int rendererVersion;
  final String title;
  final String? learningObjective;
  final CanvasDto canvas;
  final List<AnimationAssetRefDto> assets;
  final List<AnimationObjectDto> objects;
  final Map<String, dynamic> initialState;
  final List<AnimationStepDto> steps;
  final Map<String, dynamic> interactions;
  final String? narration;
  final List<String> sourceReferences;
  final String? disclaimer;
}

class AnimationStepDto {
  final String id;
  final String title;
  final String? narration;
  final String? hint;
  final int durationMs;
  final Map<String, dynamic> targetState;
  final String easing;
  final List<String> effects;
  final Map<String, dynamic>? interactions;
}

class AnimationObjectDto {
  final String id;
  final String type;
  final Offset position;
  final double scale;
  final double rotation;
  final bool visible;
  final int layer;
}
```

`fromJson(Map<String, dynamic>)` factory + `tryParse` returning null on error.

### Step 6: Flutter — AnimationSceneRenderer interface

```dart
abstract class AnimationSceneRenderer {
  String get rendererCode;
  HistoricalScenePainter createPainter(AnimationManifestDto manifest,
      AnimationAssetResolver resolver);
  HistoricalAnimationDefinition buildDefinition(AnimationManifestDto manifest);
}
```

`buildDefinition` converts manifest → `HistoricalAnimationDefinition` (existing player can render it). `createPainter` constructs the scene painter with resolved asset URLs.

### Step 7: Flutter — RiverTideRenderer

Parse manifest objects: STAKE objects → stake positions/lengths; BOAT → boat config; DECOY → decoy config. Parse `initialState`: `waterLevel`, `boatProgress`, `boatCount`, `stakes[]`, `decoyProgress`, `counterattackProgress`, `hasWaterControl`, `obstructed`. Parse each step's `targetState` → `RiverSceneState`. Build `RiverScenePainter` with stake field from manifest (no longer hardcoded `_stakeField`).

### Step 8: Flutter — JourneyMapRenderer

Parse manifest objects: MARKER → locations; ROUTE → routes; LABEL → labels; BACKGROUND → background asset. Parse `initialState`: `locations[]`, `routes[]`, `markerVisibility`, `routeProgress`, `highlightedLocationIds`, `focusedLocationId`, `tapToExplore`, `backgroundAssetId`, `disclaimer`. Build `MapScenePainter` with locations/routes from manifest.

### Step 9: Flutter — AnimationPlaybackController

Extract from `_HistoricalAnimationPlayerState` logic:
- `play()`, `pause()`, `togglePlay()`, `goToStep(int)`, `replay()`, `skip()`
- `seekTo(int step, double t)` — deterministic: apply `step.targetState` at progress t
- `dispose()` — cancel timers + controller
- Reduced motion: `MediaQuery.maybeDisableAnimationsOf(context)` → skip tween, jump to end state

### Step 10: Flutter — ReadRenderer integration

NOTE: the embedded key is `animationManifest` (per actual `SnapshotBuilder` impl), not `animationScene`.

```dart
// In ReadRenderer.build:
final animRef = config['animationManifest'] as Map<String, dynamic>?;
if (animRef != null) {
  final manifest = AnimationManifestDto.tryParse(animRef['manifest']);
  if (manifest != null) {
    final renderer = AnimationRuntimeRegistry.resolve(manifest.rendererCode);
    if (renderer != null) {
      final definition = renderer.buildDefinition(manifest);
      return HistoricalAnimationPlayer(key: ..., definition: definition);
    }
    // rendererCode unknown → fallback
  }
}
// Legacy path (unchanged):
final animation = HistoricalAnimationRegistry.resolve(configText(config, ['animationKey']));
```

### Step 11: Flutter — AnimationAssetResolver

```dart
class AnimationAssetResolver {
  final Map<String, String> _urlByAssetId;
  AnimationAssetResolver(List<dynamic> snapshotAssets) {
    for (final a in snapshotAssets) {
      _urlByAssetId[a['id']] = resolveAssetUrl(a);
    }
  }
  String? resolve(String assetId) => _urlByAssetId[assetId];
}
```

Reads `snapshot.assets[]` array (already embedded by SnapshotBuilder) → maps `id` → `storageKey` → constructs content URL via existing pattern.

### Step 12: Tests

- `animation_manifest_dto_test.dart` — parse valid manifest, missing fields, malformed JSON.
- `river_tide_renderer_test.dart` — buildDefinition produces valid HistoricalAnimationDefinition with correct steps/states.
- `journey_map_renderer_test.dart` — same for map.
- `animation_playback_controller_test.dart` — play/pause/seek/replay/skip, reduced motion.

## Todo List

- [x] `ValidationContext` extended with `validSceneVersionIds`/`publishedSceneIds`
- [x] `ReadValidator` validates `animationSceneId`/`animationSceneVersionId`/`playbackMode` (whitelist AUTO/STEPPED/INTERACTIVE)
- [x] `DraftValidator`/publish path resolves scene version ids (verify in `DraftValidator` impl)
- [ ] `PublishReadinessEvaluator` returns 422 for missing scene version — verify integration test exists
- [x] `SnapshotBuilder` embeds manifest under `config.animationManifest` + collects asset refs
- [ ] `LearnerProjectionService` verified to pass through `animationManifest` config key — needs a test
- [ ] `AnimationManifestDto` + sub-DTOs with `fromJson`/`tryParse`
- [ ] `AnimationRuntimeRegistry` — map rendererCode → renderer
- [ ] `AnimationSceneRenderer` interface
- [ ] `RiverTideRenderer` — manifest → RiverScenePainter + states
- [ ] `JourneyMapRenderer` — manifest → MapScenePainter + states
- [ ] `AnimationAssetResolver` — assetId → URL
- [ ] `AnimationPlaybackController` — extracted from player
- [ ] `ReadRenderer` — animationScene → manifest → registry → player; fallback paths
- [ ] Unit tests for all new classes
- [ ] `flutter test` passes; `flutter analyze` 0 issues

## Success Criteria

- Backend: `POST /admin/lessons/{id}/publish` with `animationSceneVersionId` embeds manifest under `config.animationManifest` → 200.
- Backend: publish with non-existent `animationSceneVersionId` → 422 `ANIMATION_SCENE_VERSION_NOT_FOUND` (matches implemented `ErrorCode`).
- Flutter: `AnimationManifestDto.tryParse` returns valid DTO for all 3 seed manifests.
- Flutter: `RiverTideRenderer.buildDefinition` produces `HistoricalAnimationDefinition` matching `bachDang938TideV1` behavior.
- Flutter: `JourneyMapRenderer.buildDefinition` produces `HistoricalAnimationDefinition` matching `haiBaTrung40UprisingV1` and `lyThaiTo1010RelocationV1`.
- Flutter: unknown `rendererCode` → falls back to text READ (no crash).
- Flutter: `animationKey` legacy path still renders `HistoricalAnimationPlayer`.
- `mvnw.cmd test` + `flutter test` + `flutter analyze` all pass.

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Manifest schema drift between backend validator and Flutter DTO | Keep schemaVersion=1 locked; both sides validate against same field whitelist; integration test parses all 3 seed manifests on both sides. |
| Painter hardcodes (stake positions, map locations) leak into renderer | Renderers must construct painter from manifest objects — not reuse `RiverScenePainter._stakeField`. Refactor painter to accept stake field as constructor param. |
| Legacy animationKey breaks | Keep `HistoricalAnimationRegistry.resolve()` untouched; READ renderer checks animationScene first, then animationKey. |
| Asset resolution fails at runtime | `AnimationAssetResolver` returns null → renderer skips asset, renders schematic fallback. |

## Security Considerations

- Manifest JSON bounded by backend validator (size/depth/count limits).
- No executable code — only whitelisted object types, easing, effects.
- Draft manifest never sent to learner — only embedded `snapshot_json` from published scene version.
- `LEARNER_HIDDEN_KEYS` does not contain animation fields — verify manifest fields don't accidentally match hidden key names (e.g., avoid field named "answer" or "key" in manifest).

## Next Steps

→ Phase 3: Admin Animation Builder UI (Next.js) consuming the Phase 1 APIs.
→ Phase 4: Seed migration + versioning cases + security hardening.
