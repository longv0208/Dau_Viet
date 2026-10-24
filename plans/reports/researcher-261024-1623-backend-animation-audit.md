# Backend Animation Scene Audit (dau-viet-backend)

Package root: `com.dauviet.animation` under `E:/Telegram Desktop/Dau viet/Dau_Viet/dau-viet-backend/src/main/java/com/dauviet/`.

## 1. AnimationTemplate (table `animation_templates`)
File: `animation/domain/AnimationTemplate.java`
- Fields: `id UUID`, `code String(64) UNIQUE`, `name`, `description text`, `rendererCode String(48)`, `rendererVersion int`, `schemaVersion int`, `capabilitiesJson jsonb`, `defaultConfigJson jsonb`, `thumbnailAssetId UUID`, `enabled`, `createdAt`, `updatedAt`. No `@Version`.
- `rendererCode` is stored as String; valid values live in `AnimationManifestSchema.RENDERER_CODES = {"RIVER_TIDE","JOURNEY_MAP"}` — enforced at `AnimationTemplateService.create()` line 57, NOT a DB enum.
- Scenes FK to templates via `animation_scenes.template_id`.

## 2. AnimationScene (table `animation_scenes`)
File: `animation/domain/AnimationScene.java`
- Fields: `id`, `templateId` (updatable=false), `eventId` (nullable), `title`, `draftJson` (JSONB — editable manifest), `status` (enum `AnimationSceneStatus` = DRAFT|PUBLISHED|ARCHIVED), `currentVersionId` (FK composite to `animation_scene_versions(id,scene_id)` DEFERRABLE), `createdBy`, `updatedBy`, `createdAt`, `updatedAt`, `@Version Long rowVersion` (optimistic lock).
- DTOs in `animation/api/dto/AnimationDtos.java` (records): `SceneCreateRequest{templateId,eventId,title,draftJson}`, `SceneUpdateRequest{title,eventId,clearEvent,draftJson,expectedRowVersion}`, `SceneResponse`, `SceneSummaryResponse`, `PublishRequest{expectedRowVersion}`, `PublishResponse{sceneId,versionId,versionNo,status,publishedAt}`, `SceneValidationResponse{ready,errors}`, `SceneVersionSummary`, `SceneVersionDetail`.
- DB checks (V14): `chk_animation_scene_status` IN list; `chk_animation_scene_published_version` — status=PUBLISHED requires `current_version_id` NOT NULL.

## 3. AnimationSceneVersion (table `animation_scene_versions`)
File: `animation/domain/AnimationSceneVersion.java`
- All cols `updatable=false`: `id`, `sceneId`, `versionNo`, `schemaVersion`, `rendererCode`, `rendererVersion`, `snapshotJson` (JSONB — full validated manifest + embedded asset metadata), `manifestChecksum varchar(64)` (SHA-256 hex of canonical snapshot text), `publishedAt`, `publishedBy`.
- Immutability enforced by DB trigger `trg_animation_scene_versions_immutable` (V14) — BEFORE UPDATE/DELETE raises.
- `UNIQUE(scene_id, version_no)` + `UNIQUE(id, scene_id)` for the composite FK from `animation_scenes.current_version_id`.
- V18 changed `manifest_checksum` from CHAR(64) to VARCHAR(64) for Hibernate validate.

## 4. animation_scene_asset_refs
File: `animation/domain/AnimationSceneAssetRef.java`
- Composite PK `(scene_version_id, asset_id, role)` via `@IdClass Key`.
- Written by `AnimationScenePublishService.publish()` after version insert; `AssetRef{manifestKey, assetId, role}` collected from `manifest.assets[].{id,assetId,role}` and `manifest.map.backgroundAssetId` (role="BACKGROUND").
- Purpose: `ASSET_IN_USE` retirement check — a published manifest cannot lose its asset binding.

## 5. AdminAnimationSceneController
File: `animation/api/AdminAnimationSceneController.java`
Base path `/api/v1/admin/animation-scenes`. No `@PreAuthorize` — auth enforced by `SecurityConfig` path rule `requestMatchers("/api/v1/admin/**").hasRole("CONTENT_ADMIN")`.
Endpoints:
- `POST /` (201) — create from `SceneCreateRequest`
- `GET /` — list (page/size/sort/templateId/eventId/status/q) → `PageResponse<SceneSummaryResponse>`
- `GET /{id}` — `SceneResponse`
- `PATCH /{id}` — `SceneUpdateRequest` → `SceneResponse`
- `POST /{id}/duplicate` (201) — `SceneResponse`
- `POST /{id}/archive` — `SceneResponse`
- `POST /{id}/validate` — `SceneValidationResponse` (always 200, read-only probe)
- `POST /{id}/publish` — optional `PublishRequest` → `PublishResponse`
- `GET /{id}/versions` — `List<SceneVersionSummary>`
- `GET /{id}/versions/{versionId}` — `SceneVersionDetail`
adminId extracted from `jwt.getSubject()` → UUID.

Sibling: `AdminAnimationTemplateController` `/api/v1/admin/animation-templates` (POST/GET/GET/PATCH).

## 6. AnimationSceneService + AnimationScenePublishService
- `AnimationSceneService.create()` (`application/AnimationSceneService.java:73`): template must exist + enabled; event FK validated; if `draftJson` absent seeds from `template.defaultConfigJson`; status DRAFT.
- `update()` line 135: `checkVersion(expectedRowVersion)` → `ObjectOptimisticLockingFailureException` when mismatch; ARCHIVED scenes reject edits; `draftJson` must be JSON object.
- `duplicate()` line 164: deep-copies to new UUID, status DRAFT, `title + " (bản sao)"`, no versions copied.
- `validate()` line 196: read-only manifest probe → `validator.validate(manifest, template)`.
- `AnimationScenePublishService.publish(sceneId, expectedRowVersion, adminId)` (line 74):
  1. `scenes.findForUpdate()` — `LockModeType.PESSIMISTIC_WRITE` (see `AnimationSceneRepository.findForUpdate`).
  2. Status≠ARCHIVED check, `expectedRowVersion` check → `ObjectOptimisticLockingFailureException`.
  3. `validator.validate(manifest, template)` → `ManifestValidationException` if non-empty.
  4. `snapshot = manifest.deepCopy()`; `snapshot.set("assets", embedAssets(...))` — replaces `assets[]` with `{id, assetId, role, storageKey, mimeType, sizeBytes, originalFilename?, altText?}` per `Asset` row.
  5. `snapshotText = write(snapshot)`; `versionNo = latest.versionNo + 1 | 1`; `schemaVersion = manifest.path("schemaVersion").asInt()` (true label, not CURRENT).
  6. Inserts `AnimationSceneVersion` + `manifestChecksum = sha256(snapshotText)` (UTF-8 SHA-256 hex).
  7. Records `AnimationSceneAssetRef` rows for each AssetRef.
  8. `scene.status=PUBLISHED`, `currentVersionId=saved.id` in same TX. UNIQUE(scene_id,version_no) is backstop.

## 7. Learner fetch
- `LearnerAssetController` `lesson/api/LearnerAssetController.java` → `GET /api/v1/assets/{id}/content`. Returns `FileSystemResource` with `Content-Type=mime`, `Content-Length`, `Content-Disposition: inline; filename=...`. Auth: `anyRequest().authenticated()` — any valid JWT (LEARNER or CONTENT_ADMIN). Loads only ACTIVE assets via `AssetService.content(id)`; path `storageDir.resolve(id + "." + ext)` with `startsWith(storageDir)` traversal guard.
- There is NO dedicated learner animation-scene fetch endpoint — manifests reach Flutter only via the lesson snapshot embedded inside `lesson_versions.snapshot_json` (see §8). Learner lesson endpoints under `/api/v1/lessons/*` require `.authenticated()` per `SecurityConfig` line 67.

## 8. SnapshotBuilder
File: `lesson/draft/SnapshotBuilder.java`
- `build(Lesson, JsonNode draft, LessonTemplate)` returns `ObjectNode` written to `lesson_versions.snapshot_json` (schemaVersion, lessonId, title, centralQuestion, objectives, templateCode, stages, completion, evidence[], assets[]).
- `embedAnimationScenes(stages)` (line 95): for every `activity.config.animationSceneVersionId` (or `animationSceneId` → resolves `findTopBySceneIdOrderByVersionNoDesc` to pin latest), loads `AnimationSceneVersion` and writes into `config.animationManifest`:
  ```
  config.animationManifest = {
    "manifest": <parsed snapshotJson>,
    "sceneVersionId": "<uuid>",
    "versionNo": <int>,
    "rendererCode": "<str>",
    "rendererVersion": <int>
  }
  ```
- `manifestChecksum` is NOT duplicated into the lesson snapshot — learner uses `sceneVersionId` + manifest already embedded. Asset IDs inside `manifest.assets[]` are re-collected via `collectManifestAssetIds` so `snapshot.assets[]` at lesson level also embeds their `{id, storageKey, mimeType, sizeBytes, originalFilename?, altText?}` rows.
- Parse failures only `log.warn` + skip embed (does not throw — relies on earlier publish validation).

## 9. Asset storage
- `dauviet.assets.dir` defined in `application.yml` line 46: `${DAUVIET_ASSETS_DIR:data/assets}` — relative to CWD.
- Table name is `assets` (not `learning_assets`); DDL in `V3__authoring_publishing_evidence_assets.sql` line 3. Entity `lesson/domain/Asset.java` fields: `id`, `storageKey` (unique), `originalFilename`, `mimeType`, `sizeBytes`, `checksumSha256` (CHAR(64) via `SqlTypes.CHAR`), `state` (`UPLOADING|ACTIVE|RETIRED|FAILED`), `altText`, `createdAt`, `createdBy`, `retiredAt`.
- Bytes stored on disk at `{dauviet.assets.dir}/{assetId}.{ext}` where `ext` is derived from mime map `ALLOWED_MIME_EXT` (`image/png|jpeg|webp`, `audio/mpeg|wav|x-wav|ogg`). `storageKey` field = `"assets/{id}.{ext}"` (kept as object-storage stable key).
- Serving: `AssetService.content(UUID)` → `StoredAsset(path, mimeType, filename, sizeBytes)`; consumed by `LearnerAssetController` and `AdminAssetController` (admin route `/api/v1/admin/assets/{id}/content`).

## 10. Flyway migrations V14–V19
Files under `src/main/resources/db/migration/`:
- `V14__animation_engine.sql` — all four tables + immutability trigger + composite FK.
- `V15__animation_seed.sql` — 2 templates + 3 published scenes (checksum recipe `encode(digest(snapshot_text,'sha256'),'hex')`).
- `V16__animation_cinematic_demos.sql` — 3 v2 cinematic demo scenes + a silent-WAV asset row.
- `V17__bachdang_production_scene.sql` — production Bạch Đằng v2 scene with real assets.
- `V18__animation_scene_versions_checksum_varchar.sql` — `manifest_checksum` CHAR→VARCHAR(64).
- V19 is FREE. No `V19__*.sql` exists.

## 11. Multipart upload precedent
- `AdminAssetController.upload` (`lesson/api/AdminAssetController.java:53`): `POST /api/v1/admin/assets` `consumes=MULTIPART_FORM_DATA`, `@RequestPart("file") MultipartFile`, optional `altText` `@RequestParam`. Returns `AssetResponse` (201).
- Limits: `application.yml` `spring.servlet.multipart.max-file-size=10MB`, `max-request-size=12MB`.
- Validation in `AssetService.upload()` line 59: non-empty, ≤10MB, mime in `ALLOWED_MIME_EXT` whitelist (image/png jpeg webp; audio/mpeg wav x-wav ogg). Writes to disk, computes SHA-256 via `Files.readAllBytes`+`MessageDigest`, marks ACTIVE.
- HTML scene upload would need a new mime entry (e.g. `text/html`) — currently rejected by `ALLOWED_MIME_EXT`.

## 12. AnimationManifestValidator
File: `animation/manifest/AnimationManifestValidator.java` (~1070 lines). Returns `List<ManifestFieldError>` — never throws. Template-aware (`validate(JsonNode manifest, AnimationTemplate template)`).
- Whitelist-driven: `TOP_LEVEL_KEYS`, `OBJECT_TYPES`, `EASINGS`, `EFFECTS`, `INTERACTIONS`, `ASSET_ROLES`, `EFFECT_TYPES_V2`, `AUDIO_CUES`, `TRACK_PROPERTIES`, per-renderer `STATE_KEYS` from `AnimationManifestSchema`.
- Enforces: `schemaVersion>=1` (≤ CURRENT or template), `rendererCode` ∈ `RENDERER_CODES` AND must equal `template.rendererCode`, `rendererVersion ≤ template.rendererVersion`, `title`, valid `assets[]` (each `assetId` must be ACTIVE via `assets.existsByIdAndState`), `objects[]`, per-renderer `river`/`map` section (RIVER_TIDE → `validateRiver`; JOURNEY_MAP → `validateMap`), `steps` non-empty, `interactions` whitelist, `prediction` shape, `sourceReferences` non-empty, `disclaimer` required, v2 keys gate (`camera/tracks/effects/audio/environment` ⇒ `schemaVersion>=2`).
- A no-manifest HTML scene WOULD FAIL: `steps` required, `sourceReferences` required, `disclaimer` required, `rendererCode` must match template — no HTML/free-form escape hatch. Adding an "HTML_SCENE" renderer requires new entries in `RENDERER_CODES` + a `validate*` branch + `STATE_KEYS` row, or a different publish path that skips this validator.

## 13. Auth
- No `@PreAuthorize` on controllers — enforcement is path-based in `common/config/SecurityConfig.java`:
  - `requestMatchers("/api/v1/admin/**").hasRole("CONTENT_ADMIN")` (line 72).
  - `GET /api/v1/events`, `/api/v1/events/*` — `permitAll`.
  - `GET /api/v1/events/*/lessons`, `/api/v1/lessons`, `/api/v1/lessons/*`, `/api/v1/lessons/*/content` — `authenticated` (any role).
  - `POST /api/v1/auth/**` — `permitAll`.
  - `anyRequest().authenticated()` — covers `/api/v1/assets/{id}/content` and everything else.
- Role claim is extracted via `JwtAuthenticationConverter` (`security/jwt/JwtConfig.java`) producing `ROLE_CONTENT_ADMIN`/`ROLE_LEARNER` authorities.
- `adminId` parsed from `Jwt.getSubject()` → `UUID`; mismatches throw `AuthenticationFailedException`.

## Unresolved
- Whether an HTML_SCENE renderer should bypass `AnimationManifestValidator` entirely (needs new code path or an explicit template `capabilities_json` flag honoured by the validator).
- Whether HTML bundles upload via a new endpoint under `/api/v1/admin/assets` (extending `ALLOWED_MIME_EXT` with `text/html`/`application/zip`) or a separate `/api/v1/admin/animation-scenes/{id}/html` route.
- Learner fetch for HTML scenes — currently no endpoint serves raw scene HTML; the existing pattern only exposes `manifest` JSON + asset binaries.
