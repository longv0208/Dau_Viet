# Flutter READ animation dispatch audit — dau-viet-mobile

## 1. ReadRenderer dispatch (lib/features/learning/presentation/renderers/read_renderer.dart)

Class `ReadRenderer extends StatelessWidget` — fields: `activity` (ActivityRefDto), `submitting`, `onSubmit(Map<String,dynamic>)`.

Dispatch logic (build, lines ~79-99):

```dart
final parseRes = AnimationRuntimeRegistry.parseManifestDetailed(config['animationManifest']);
final manifestDto = parseRes.dto;
final manifestRenderer = manifestDto == null ? null : AnimationRuntimeRegistry.resolve(manifestDto.rendererCode);
final playbackMode = configText(config, ['playbackMode']) ?? 'AUTO';
final bool manifestPresent = parseRes.present;
final animation = manifestPresent
    ? (manifestDto != null && manifestRenderer != null && manifestRenderer.canRender(manifestDto)
        ? manifestRenderer.build(manifestDto, playbackMode: playbackMode)
        : null)
    : HistoricalAnimationRegistry.resolve(configText(config, ['animationKey']));
```

Fields read from `activity.config`:
- `animationManifest` — preferred, embedded envelope `{manifest, sceneVersionId, versionNo, rendererCode, rendererVersion}` or bare manifest map.
- `animationKey` — legacy fallback only when `animationManifest` absent (not when invalid).
- `playbackMode` — `AUTO`/`STEPPED`/`INTERACTIVE`, default `AUTO`.
- `title/heading/passageTitle`, `subtitle/lede`, `source/attribution`, `body/text/content/passage`, `paragraphs[]`.

3-branch semantics (FIX-P1):
- `present=false` → legacy `animationKey` via `HistoricalAnimationRegistry.resolve` (map key → compiled `HistoricalAnimationDefinition`; hardcoded 3 scenes: bach_dang_938_tide_v1, hai_ba_trung_40_uprising_v1, ly_thai_to_1010_relocation_v1 at lib/features/learning/presentation/animations/historical_animation_registry.dart).
- `present=true && dto!=null && renderer!=null && canRender` → `renderer.build(manifest, playbackMode)` → `HistoricalAnimationDefinition` → `_CinematicBoundPlayer` (StatefulWidget owns `ValueNotifier<CinematicFrame>` initialized to `manifest.cinematic.cameraInitial`) → `HistoricalAnimationPlayer(definition, manifest, cinematicFrame)`.
- `present=true` but invalid/unsupported → `_UnsupportedAnimationNotice` (no crash, no silent fallback to animationKey — guards against wrong-scene mount).

`AnimationRuntimeRegistry` (runtime/animation_runtime_registry.dart): `_renderers = [RiverTideRenderer(), JourneyMapRenderer()]`; `resolve(rendererCode)` returns `AnimationSceneRenderer?`; `supportedCodes` = ['RIVER_TIDE','JOURNEY_MAP']. `parseManifestDetailed` reads `embedded['manifest'] ?? embedded` — envelope unwrapping happens here; `rendererCode` must be non-empty else `invalid`.

## 2. ManifestAssetLayers (widgets/manifest_asset_layers.dart)

`ManifestAssetLayers` — StatelessWidget, fields: `manifest`, `aspectRatio`, `child` (the CustomPaint painter canvas), `frameListenable` (`ValueListenable<CinematicFrame>?`).

- `_backgroundAssetId`: prefer `manifest.backgroundAssetId` (map.backgroundAssetId) else first `assetRefs` entry with `role=='BACKGROUND'`.
- `_objectLayers`: filters `manifest.objects` where `visible==true`; resolves each object's `assetRef` → `assetRefs` by `id`; keeps only entries with an OBJECT-role ref OR a procedural type in whitelist `{STAKE,BOAT,DECOY,MARKER,LABEL,ROUTE,LOCATION,WATER,TEXT}`; sorts by `layer`.
- `_hasCinematic` if `camera.steps`/`tracks`/`effects` non-empty; `_hasEnvironment` if `environment.mist>0||glow>0`.
- Early-exit: no bg + no objects + no cinematic + no environment → return `child` unchanged.
- Render: `LayoutBuilder` → `_sceneStack` = `Stack(fit:expand)` children in order: `_ManifestImage` (bg, `frame:false`, opacity 0.45), `child` (painter canvas), per-object `Positioned` (x/y normalized × size, diameter = `scale×width` clamped ≥24), per-frame `ActiveEffect` overlay painters (WATER_RIPPLE/MIST/GLOW/FADE_IN/FADE_OUT via `WaterRipplePainter`/`MistPainter`/`GlowPainter`/`FadePainter` in effects/effect_painters.dart); `ROUTE_REVEAL` is delegated to painter. Then `_wrapEnvironment` adds `EnvironmentOverlay` (ambient mist/glow).
- Cinematic path: `ClipRect` + `ValueListenableBuilder<CinematicFrame>` → `Transform(transform: frame.camera.transformFor(size))` wraps whole stack — camera transform bounded to AspectRatio box only (P0 layout §2). `ObjectVisualState` per objectId consumed from `frame.objects`; GLOW with `objectId` follows that object's position.
- Objects without an OBJECT `assetRef` render `_ProceduralObjectPainter` glyphs (boat/stake/marker/label/water), matching backend OBJECT_TYPES whitelist.
- `_ManifestImage` is a `ConsumerStatefulWidget` that fetches bytes ONCE in `initState` via `fetchLearningAssetBytes(ref, assetId)` ONLY if `ref.read(authSessionProvider).isAuthenticated` (no ProviderScope → placeholder, no fetch — test-safe). Errors/empty → broken-image icon; bg errors → `SizedBox.shrink`.

`HistoricalAnimationPlayer` (`animations/historical_animation_player.dart`): builds `AspectRatio(aspectRatio: def.aspectRatio)` → ClipRRect → `_buildSceneCanvas` → `ManifestAssetLayers(manifest, aspectRatio, frameListenable: widget.cinematicFrame, child: canvas)`. Emits frames via `_emitFrame` on `_onTick` (evaluator `manifest.cinematic.frameAt(stepIndex, easedT, rawProgress)`). `_ensureAudio()` builds `AnimationAudioController` with `audioAssetIds = {a.id: a.assetId for a in manifest.assetRefs where a.role=='AUDIO'}` and `fetchBytes = fetchLearningAssetBytes(ref, id)`.

## 3. Snapshot_json → READ

- `ActivityRefDto.config` (data/attempt_dtos.dart) is a raw `Map<String,dynamic>` from `activity.config` in `GET /api/v1/attempts/{id}/current` (and submit response `next.learnerConfig` via `NextRefDto`).
- The envelope fields `sceneVersionId`, `versionNo`, `rendererCode`, `rendererVersion`, `manifest` live INSIDE `config['animationManifest']` — see `_embedded()` in test/learning/animation_runtime_test.dart lines 123-129:

```dart
{'manifest': manifest, 'sceneVersionId': 'uuid', 'versionNo': 3,
 'rendererCode': manifest['rendererCode'], 'rendererVersion': 1}
```

- `parseManifestDetailed` reads only `embedded['manifest']` (or bare map); `sceneVersionId`/`manifestChecksum` are NOT parsed into any DTO — DTO keeps only `schemaVersion`, `rendererCode`, `rendererVersion`, plus content keys. No field named `manifestChecksum` appears in mobile code (grep: only test file references sceneVersionId).
- `LessonContentDto.content` (data/learning_dtos.dart) holds `stages[]/evidence[]/assets[]` raw maps for `/attempts/{id}/content` (snapshot pinned to attempt version) — config travels via `CurrentActivityDto`, not content.

## 4. fetchLearningAssetBytes

Defined in lib/features/learning/presentation/renderers/learning_asset_image.dart:

```dart
Future<List<int>> fetchLearningAssetBytes(WidgetRef ref, String assetId) => _fetchAssetBytes(ref, assetId);
```

- Calls `repo.getAssetBytes(assetId)` where repo = `ref.read(attemptRepositoryProvider)` → `LearningApiClient.getAssetBytes` → `GET /api/v1/assets/{assetId}/content` via `ApiClient.getBytes` (Dio `ResponseType.bytes`).
- Auth: `ApiClient._authOptions` injects `Authorization: Bearer <token>` from `static String? Function()? authTokenProvider` (set by AuthRepository). When `ApiConfig.useMock` false, call is wrapped: `ref.read(authRepositoryProvider).withAuth(() => repo.getAssetBytes(assetId))` (withAuth likely handles refresh). Mock mode bypasses withAuth.
- In-memory byte cache `_assetByteCache` (max 24, FIFO) keyed by assetId with a session tag; owner change (logout/account switch) clears. Errors/empty self-evict.
- Base URL: `ApiConfig.baseUrl` (core/api/api_config.dart) — `--dart-define=API_BASE_URL`, else `http://10.0.2.2:8080` on Android, `http://localhost:8080` elsewhere. `USE_MOCK=true` switches repo to mock.

## 5. pubspec.yaml (dau-viet-mobile/pubspec.yaml)

- SDK: `sdk: ^3.12.0` (Dart; Flutter version implicit).
- Deps: `flutter_riverpod ^3.4.3`, `go_router ^18.0.2`, `google_fonts ^8.2.1`, `audioplayers ^6.8.1`, `dio ^5.7.0`, `flutter_secure_storage ^11.2.0`, `shared_preferences ^2.3.0`, `uuid ^4.6.0`, `cupertino_icons ^1.0.8`. Dev: `flutter_test`, `flutter_lints ^6.0.0`.
- NO `webview_flutter` — animations are pure CustomPaint + image layers; no webview.
- Assets: `assets/images/`, `assets/badges/`, `assets/items/`, `assets/audio/` bundled.
- No explicit Android `minSdkVersion`/`compileSdk` or iOS `IPHONEOS_DEPLOYMENT_TARGET` in pubspec (would be in android/app/build.gradle / ios/Podfile — not read here).

## 6. Audio/BACKGROUND asset plumbing

- `assets[]` manifest entries: `{id (manifest key), assetId (backend uuid), role: BACKGROUND|OBJECT|AUDIO, altText?}`. Parsed by `AnimationManifestDto._assetRefs` → `AnimationAssetRefDto{id, assetId, role}`.
- BACKGROUND → `ManifestAssetLayers._backgroundAssetId` → `_ManifestImage` fetch by `assetId` via `/api/v1/assets/{assetId}/content` (NOT storageKey — snapshot pins id).
- AUDIO → `HistoricalAnimationPlayer._ensureAudio()` builds `audioAssetIds = {manifestKey.id → assetId}` for role AUDIO; `AnimationAudioController(fetchBytes: (id) => fetchLearningAssetBytes(ref, id), audioAssetIds, cues)`; cues fire on `onStepEnter/onStepExit` via stepId; LOOP player exclusive; bytes cached per assetId in controller `_byteCache`. Plugin = audioplayers `AudioPlayer` + `BytesSource`; `CueAudioPlayerFactory` is a test seam.
- OBJECT → `_ManifestImage` with `frame:true`, `shape` circle/rect.
- `animation_asset_resolver.dart` (`AnimationAssetResolver`) handles DRAFT-shape assets (id/uuid/storageKey) for admin preview — different from snapshot path.

## 7. READ acknowledgment

`ReadRenderer` bottom `SubmitBar(label: 'ĐÃ ĐỌC XONG, TIẾP TỤC', onPressed: () => onSubmit(const {}))` — empty-map answer.

`LessonPlayerScreen._submit` (lesson_player_screen.dart ~L159): mints `Idempotency-Key` (`Uuid().v4()`) per fresh answer, calls `AttemptRepository.submit(attemptId, activityId, {}, idempotencyKey)` → `LearningApiClient.submit` → `POST /api/v1/attempts/{attemptId}/activities/{activityId}/submissions` body `{'answer': {}}`. Retry of same payload reuses key; `IDEMPOTENCY_CONFLICT` → user-visible error. Server returns `SubmitResultDto` → `_applyResult` (progress/next/completion). No client-side grading — server marks COMPLETED.

## 8. Test helpers (test/learning/animation_runtime_test.dart)

- `_riverManifest()` / `_mapManifest()` — minimal valid manifest JSON per renderer.
- `_embedded(manifest)` — wraps manifest in `{manifest, sceneVersionId, versionNo, rendererCode, rendererVersion}` envelope.
- `_readActivity(config)` — builds `ActivityRefDto` with `type:'READ'`.
- `_pumpRead(tester, config)` — pumps `MaterialApp > MediaQuery(800x1600) > Scaffold > SingleChildScrollView > ReadRenderer(activity, submitting:false, onSubmit:(_)async{})`.
- Patterns: `find.byType(HistoricalAnimationPlayer)` presence/absence; `find.byType(Slider)` for river water control; `find.textContaining('cần phiên bản ứng dụng mới hơn')` for unsupported notice; `tester.takeException()` null; `ensureVisible` + tap 'Bước tiếp'/'Bước trước' semantics labels for step nav.
- `read_renderer_manifest_test.dart` exists separately for manifest-specific READ cases.

## Open questions
- `manifestChecksum`: not found in mobile code — backend-side only? Confirm whether snapshot envelope carries it and app should verify.
- `authRepositoryProvider.withAuth` — actual implementation (refresh token?) in features/auth/data/auth_repository.dart not read.
- Android minSdk / iOS deployment target in native folders not audited.
