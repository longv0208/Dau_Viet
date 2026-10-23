# Phase 1 — Backend Domain, Database & Admin API

## Context Links

- `docs/API_SPEC.md` — API contract patterns, error envelope, status codes
- `docs/DATABASE_DESIGN.md` — ERD, JSONB policy, immutable snapshot pattern
- `dau-viet-backend/src/main/resources/db/migration/V3__authoring_publishing_evidence_assets.sql` — `prevent_lesson_version_mutation()` trigger pattern
- `dau-viet-backend/src/main/resources/db/migration/V8__map_locations.sql` — CHECK + composite FK + index pattern
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LessonPublishService.java` — pessimistic lock + optimistic checkVersion + version_no=max+1 pattern
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/Lesson.java` — entity pattern (UUID, JSONB via `@JdbcTypeCode`, `@Version`)
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/AdminLessonController.java` — admin controller pattern

## Overview

- **Priority:** P1 (blocks all other phases)
- **Status:** completed (uncommitted in working tree; verify `mvnw.cmd test` passes before closing)
- **Effort:** 5h

**State:** `com.dauviet.animation` package + `V14__animation_engine.sql` already exist and match this spec — 4 tables, immutable trigger, `AnimationManifestValidator` with all ~15 checks, `AdminAnimationTemplateController` + `AdminAnimationSceneController`, exceptions wired into `GlobalExceptionHandler`, `ErrorCode` enum extended. Remaining work for Phase 1 is test coverage (`dau-viet-backend/src/test/java/com/dauviet/animation/**` is empty) and a manual sanity pass on the publish concurrency path.

Create the `com.dauviet.animation` module: Flyway migration V14, JPA entities, repositories, DTOs, services, validators, and admin REST controllers for Animation Templates and Animation Scenes.

## Key Insights

- `lesson_versions` uses `UNIQUE (lesson_id, version_no)` + composite FK `(current_version_id, id) → lesson_versions(id, lesson_id)` to guarantee same-lesson reference. Apply identical pattern for scenes.
- Optimistic locking is done manually via `checkVersion()` comparing `expectedRowVersion` against `@Version` field, throwing `ObjectOptimisticLockingFailureException` → handled by existing exception mapper to 409 `OPTIMISTIC_LOCK_CONFLICT`.
- Pessimistic publish lock uses `findForUpdate()` with `@Lock(PESSIMISTIC_WRITE)` on the repository.
- `draft_json`/`snapshot_json` are `String` fields with `@JdbcTypeCode(SqlTypes.JSON)` and `columnDefinition = "jsonb"`.
- `ValidationContext` carries `eventId`, `level`, `validEvidenceIds`, `activeAssetIds` — validators stay persistence-free; callers resolve lookups.

## Requirements

### Functional

1. `animation_templates` table: code (unique), name, renderer_code, schema_version, capabilities_json, default_config_json, thumbnail_asset_id (FK→assets), enabled, timestamps, row_version.
2. `animation_scenes` table: template_id (FK), event_id (FK→historical_events, nullable), title, draft_json, status (DRAFT/PUBLISHED/ARCHIVED), current_version_id, created_by/updated_by, timestamps, row_version.
3. `animation_scene_versions` table: scene_id (FK), version_no, schema_version, renderer_code, renderer_version, snapshot_json, manifest_checksum, published_at, published_by. UNIQUE(scene_id, version_no). Immutable trigger.
4. `animation_scene_asset_refs` table: scene_version_id (FK), asset_id (FK), role. UNIQUE(scene_version_id, asset_id, role).
5. Admin APIs under `/api/v1/admin/animation-templates` and `/api/v1/admin/animation-scenes` with CONTENT_ADMIN authz.
6. Full CRUD + duplicate/validate/publish/archive/versions endpoints.
7. `AnimationManifestValidator` (~15 checks) returning `FieldError[]` {path, code, message}.
8. Publish flow: pessimistic lock → validate → version_no=max+1 → insert version → update current_version_id+status, all in one transaction.
9. `manifest_checksum` = SHA-256 hex of canonical snapshot_json (sorted keys, no whitespace).

### Non-functional

- All timestamps UTC `timestamptz`.
- No cascade delete on published content (same policy as lessons).
- Indexes on (template_id, status), (event_id, status), (scene_id, published_at DESC).
- JSONB columns validated as objects at DB level via CHECK `jsonb_typeof`.

## Architecture

```
Admin API Layer
├── AdminAnimationTemplateController  /api/v1/admin/animation-templates
├── AdminAnimationSceneController     /api/v1/admin/animation-scenes
└── AdminAnimationSceneVersionController /api/v1/admin/animation-scenes/{id}/versions

Application Layer
├── AnimationTemplateService          (CRUD, list, get)
├── AnimationSceneService             (CRUD, draft update, duplicate, archive, validate)
└── AnimationScenePublishService      (pessimistic lock → validate → version → rotate)

Domain Layer
├── AnimationTemplate, AnimationScene, AnimationSceneVersion, AnimationSceneAssetRef
├── AnimationSceneStatus enum (DRAFT/PUBLISHED/ARCHIVED)
└── AnimationManifestValidator        (~15 checks → List<FieldError>)

Infrastructure
├── AnimationTemplateRepository       (findForUpdate)
├── AnimationSceneRepository          (findForUpdate, findTopBySceneIdOrderByVersionNoDesc)
└── AnimationSceneVersionRepository

Draft/Manifest
├── AnimationManifestSchema           (constants: CURRENT_VERSION, whitelists, bounds)
└── manifest field whitelist per renderer code
```

## Related Code Files

### Create

| File | Purpose |
|------|---------|
| `dau-viet-backend/src/main/resources/db/migration/V14__animation_engine.sql` | Tables + trigger + indexes |
| `dau-viet-backend/src/main/java/com/dauviet/animation/domain/AnimationTemplate.java` | Entity |
| `dau-viet-backend/src/main/java/com/dauviet/animation/domain/AnimationScene.java` | Entity |
| `dau-viet-backend/src/main/java/com/dauviet/animation/domain/AnimationSceneVersion.java` | Entity |
| `dau-viet-backend/src/main/java/com/dauviet/animation/domain/AnimationSceneAssetRef.java` | Entity |
| `dau-viet-backend/src/main/java/com/dauviet/animation/domain/AnimationSceneStatus.java` | Enum |
| `dau-viet-backend/src/main/java/com/dauviet/animation/domain/AnimationTemplateNotFoundException.java` | Exception |
| `dau-viet-backend/src/main/java/com/dauviet/animation/domain/AnimationSceneNotFoundException.java` | Exception |
| `dau-viet-backend/src/main/java/com/dauviet/animation/domain/AnimationValidationException.java` | Exception (wraps FieldError list) |
| `dau-viet-backend/src/main/java/com/dauviet/animation/infrastructure/persistence/AnimationTemplateRepository.java` | JPA repo + findForUpdate |
| `dau-viet-backend/src/main/java/com/dauviet/animation/infrastructure/persistence/AnimationSceneRepository.java` | JPA repo + findForUpdate + versionNo query |
| `dau-viet-backend/src/main/java/com/dauviet/animation/infrastructure/persistence/AnimationSceneVersionRepository.java` | JPA repo |
| `dau-viet-backend/src/main/java/com/dauviet/animation/infrastructure/persistence/AnimationSceneAssetRefRepository.java` | JPA repo |
| `dau-viet-backend/src/main/java/com/dauviet/animation/application/AnimationTemplateService.java` | Template CRUD |
| `dau-viet-backend/src/main/java/com/dauviet/animation/application/AnimationSceneService.java` | Scene CRUD/draft/duplicate/archive/validate |
| `dau-viet-backend/src/main/java/com/dauviet/animation/application/AnimationScenePublishService.java` | Transactional publish |
| `dau-viet-backend/src/main/java/com/dauviet/animation/draft/AnimationManifestSchema.java` | Constants + whitelists |
| `dau-viet-backend/src/main/java/com/dauviet/animation/draft/AnimationManifestValidator.java` | ~15 validation checks |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/AdminAnimationTemplateController.java` | REST |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/AdminAnimationSceneController.java` | REST |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/AdminAnimationSceneVersionController.java` | REST (read-only versions) |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/dto/AnimationTemplateCreateRequest.java` | DTO |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/dto/AnimationTemplateUpdateRequest.java` | DTO |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/dto/AnimationTemplateResponse.java` | DTO |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/dto/AnimationSceneCreateRequest.java` | DTO |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/dto/AnimationSceneUpdateRequest.java` | DTO |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/dto/AnimationSceneResponse.java` | DTO |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/dto/AnimationSceneSummaryResponse.java` | DTO (list) |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/dto/AnimationSceneVersionSummary.java` | DTO |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/dto/AnimationSceneVersionDetail.java` | DTO |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/dto/AnimationPublishRequest.java` | DTO |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/dto/AnimationPublishResponse.java` | DTO |
| `dau-viet-backend/src/main/java/com/dauviet/animation/api/dto/AnimationValidateResponse.java` | DTO {ready, errors[], warnings[]} |
| `dau-viet-backend/src/test/java/com/dauviet/animation/AnimationTemplateIT.java` | Integration test |
| `dau-viet-backend/src/test/java/com/dauviet/animation/AnimationScenePublishIT.java` | Integration test |
| `dau-viet-backend/src/test/java/com/dauviet/animation/AnimationManifestValidatorTest.java` | Unit test |

### Modify

| File | Change |
|------|--------|
| `dau-viet-backend/src/main/java/com/dauviet/common/api/PageResponse.java` | Reuse (no change needed — verify it works with new page types) |

## Implementation Steps

### Step 1: Flyway V14__animation_engine.sql

```sql
-- animation_templates
CREATE TABLE animation_templates (
    id UUID PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    renderer_code VARCHAR(48) NOT NULL,
    schema_version INTEGER NOT NULL CHECK (schema_version >= 1),
    capabilities_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    default_config_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    thumbnail_asset_id UUID REFERENCES assets(id),
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_anim_tpl_caps CHECK (jsonb_typeof(capabilities_json) = 'object'),
    CONSTRAINT chk_anim_tpl_config CHECK (jsonb_typeof(default_config_json) = 'object')
);

-- animation_scenes
CREATE TABLE animation_scenes (
    id UUID PRIMARY KEY,
    template_id UUID NOT NULL REFERENCES animation_templates(id),
    event_id UUID REFERENCES historical_events(id),
    title VARCHAR(255) NOT NULL,
    draft_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    status VARCHAR(24) NOT NULL DEFAULT 'DRAFT',
    current_version_id UUID,
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_anim_scene_status CHECK (status IN ('DRAFT','PUBLISHED','ARCHIVED')),
    CONSTRAINT chk_anim_scene_draft CHECK (jsonb_typeof(draft_json) = 'object'),
    CONSTRAINT chk_anim_scene_published_version CHECK (status <> 'PUBLISHED' OR current_version_id IS NOT NULL)
);
CREATE INDEX idx_anim_scenes_template_status ON animation_scenes(template_id, status);
CREATE INDEX idx_anim_scenes_event_status ON animation_scenes(event_id, status);

-- animation_scene_versions
CREATE TABLE animation_scene_versions (
    id UUID PRIMARY KEY,
    scene_id UUID NOT NULL REFERENCES animation_scenes(id),
    version_no INTEGER NOT NULL CHECK (version_no >= 1),
    schema_version INTEGER NOT NULL CHECK (schema_version >= 1),
    renderer_code VARCHAR(48) NOT NULL,
    renderer_version INTEGER NOT NULL CHECK (renderer_version >= 1),
    snapshot_json JSONB NOT NULL,
    manifest_checksum CHAR(64) NOT NULL,
    published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_by UUID NOT NULL REFERENCES users(id),
    UNIQUE (scene_id, version_no),
    UNIQUE (id, scene_id),
    CONSTRAINT chk_anim_snapshot CHECK (jsonb_typeof(snapshot_json) = 'object')
);
CREATE INDEX idx_anim_version_scene_pub ON animation_scene_versions(scene_id, published_at DESC);

ALTER TABLE animation_scenes ADD CONSTRAINT fk_anim_scene_current_own_version
    FOREIGN KEY (current_version_id, id) REFERENCES animation_scene_versions(id, scene_id)
    DEFERRABLE INITIALLY IMMEDIATE;

-- Immutable trigger (same pattern as lesson_versions)
CREATE FUNCTION prevent_animation_version_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'animation_scene_versions are immutable; publish a new version instead';
END;
$$;
CREATE TRIGGER trg_anim_scene_versions_immutable
    BEFORE UPDATE OR DELETE ON animation_scene_versions
    FOR EACH ROW EXECUTE FUNCTION prevent_animation_version_mutation();

-- animation_scene_asset_refs
CREATE TABLE animation_scene_asset_refs (
    id UUID PRIMARY KEY,
    scene_version_id UUID NOT NULL REFERENCES animation_scene_versions(id),
    asset_id UUID NOT NULL REFERENCES assets(id),
    role VARCHAR(48) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (scene_version_id, asset_id, role)
);
CREATE INDEX idx_anim_asset_refs_version ON animation_scene_asset_refs(scene_version_id);
CREATE INDEX idx_anim_asset_refs_asset ON animation_scene_asset_refs(asset_id);
```

### Step 2: Domain entities

Create `AnimationTemplate`, `AnimationScene`, `AnimationSceneVersion`, `AnimationSceneAssetRef`, `AnimationSceneStatus` enum. Follow `Lesson.java` pattern exactly: `@Entity`, `@Table`, `@Id UUID`, `@JdbcTypeCode(SqlTypes.JSON)` for JSONB String fields, `@Version Long rowVersion`, `@CreationTimestamp`/`@UpdateTimestamp`.

### Step 3: Repositories

- `AnimationTemplateRepository`: `JpaRepository<AnimationTemplate, UUID>` + `JpaSpecificationExecutor` + `findForUpdate` (PESSIMISTIC_WRITE).
- `AnimationSceneRepository`: same + `findTopBySceneIdOrderByVersionNoDesc` → actually this goes on `AnimationSceneVersionRepository` for the version_no query.
- `AnimationSceneVersionRepository`: `findTopBySceneIdOrderByVersionNoDesc(UUID sceneId)`.
- `AnimationSceneAssetRefRepository`: standard JPA.

### Step 4: AnimationManifestSchema constants

```java
public final class AnimationManifestSchema {
    public static final int CURRENT_VERSION = 1;
    public static final Pattern ID_PATTERN = Pattern.compile("[a-z0-9][a-z0-9-]{1,63}");
    public static final Set<String> TOP_LEVEL_KEYS = Set.of(
        "schemaVersion","rendererCode","rendererVersion","title","learningObjective",
        "canvas","assets","objects","initialState","steps","interactions","narration",
        "sourceReferences","disclaimer"
    );
    public static final Set<String> OBJECT_TYPES = Set.of(
        "STAKE","BOAT","DECOY","MARKER","LABEL","ROUTE","BACKGROUND","WATER","GROUP"
    );
    public static final Set<String> EASING_TYPES = Set.of(
        "linear","easeIn","easeOut","easeInOut","easeInCubic","easeOutCubic","easeInOutCubic"
    );
    public static final Set<String> EFFECT_TYPES = Set.of(
        "fadeIn","fadeOut","highlight","pulse","drawRoute","sequenceSummary"
    );
    public static final int MAX_OBJECTS = 200;
    public static final int MAX_STEPS = 50;
    public static final int MAX_ASSETS = 50;
    public static final int MAX_JSON_DEPTH = 20;
    public static final long MAX_JSON_SIZE = 512_000; // 500KB
    public static final Set<String> RENDERER_CODES = Set.of("RIVER_TIDE","JOURNEY_MAP");
}
```

### Step 5: AnimationManifestValidator (~15 checks)

Checks (each produces `FieldError`):

1. `schemaVersion` == CURRENT_VERSION → `UNSUPPORTED_SCHEMA_VERSION`
2. `rendererCode` ∈ RENDERER_CODES → `UNSUPPORTED_RENDERER`
3. `rendererVersion` >= 1 → `INVALID_RENDERER_VERSION`
4. `rendererCode` matches template's renderer_code → `RENDERER_MISMATCH`
5. `title` non-blank → `MISSING_FIELD`
6. `canvas.aspectRatio` > 0 → `INVALID_CANVAS`
7. `objects[].id` matches ID_PATTERN + unique → `INVALID_ID`/`DUPLICATE_ID`
8. `objects[].type` ∈ OBJECT_TYPES → `UNSUPPORTED_OBJECT_TYPE`
9. `objects[].position.x/y` in [0,1] → `POSITION_OUT_OF_BOUNDS`
10. `steps[].durationMs` in [200, 30000] → `DURATION_OUT_OF_BOUNDS`
11. `steps[].easing` ∈ EASING_TYPES → `UNSUPPORTED_EASING`
12. `steps[].effects[]` ∈ EFFECT_TYPES → `UNSUPPORTED_EFFECT`
13. `assets[].assetId` exists and ACTIVE → `ASSET_NOT_FOUND`
14. No unknown top-level keys → `UNKNOWN_FIELD`
15. JSON size/depth/count within bounds → `PAYLOAD_TOO_LARGE`

Renderer-specific field validation: for `RIVER_TIDE` check `initialState` may contain waterLevel/boatProgress/stakes[] etc.; for `JOURNEY_MAP` check `initialState` may contain locations[]/routes[]/markerVisibility etc. Validate these nested fields' types and bounds.

### Step 6: Services

**AnimationTemplateService:** standard CRUD (create validates code unique, enabled flag). List with page/size/sort/q filters.

**AnimationSceneService:**
- `create` — validate template exists+enabled, optional event exists, draft_json is object.
- `update` — PATCH title/eventId; optimistic lock check.
- `updateDraft` — PUT draft_json; SAVE-level validation; optimistic lock.
- `duplicate` — copy scene (new id, title+" (copy)", status=DRAFT, copy draft_json, clear current_version_id).
- `archive` — status→ARCHIVED; 409 if already archived.
- `validate` — returns `AnimationValidateResponse` {ready, errors[], warnings[]} — always 200.

**AnimationScenePublishService:**
```java
@Transactional
public AnimationPublishResponse publish(UUID sceneId, Long expectedRowVersion, UUID adminId) {
    AnimationScene scene = scenes.findForUpdate(sceneId).orElseThrow(...);
    if (scene.getStatus() == ARCHIVED) throw ...;
    checkVersion(scene, expectedRowVersion);
    List<FieldError> errors = manifestValidator.validate(parse(scene.getDraftJson()), scene);
    if (!errors.isEmpty()) throw new AnimationValidationException(errors);
    AnimationTemplate tpl = templates.findById(scene.getTemplateId()).orElseThrow(...);
    int versionNo = sceneVersions.findTopBySceneIdOrderByVersionNoDesc(sceneId)
        .map(v -> v.getVersionNo() + 1).orElse(1);
    // build snapshot: copy draft verbatim + embed asset metadata
    // compute manifest_checksum
    // insert version row
    // update scene.current_version_id + status
    // insert asset_refs rows
}
```

### Step 7: Controllers

Follow `AdminLessonController` pattern: `@RestController`, `@RequestMapping("/api/v1/admin/...")`, `@Validated`, `adminId(Jwt)` helper, `parseSort` with whitelisted fields.

**AdminAnimationTemplateController:**
- `GET /` — list (page/size/sort/q)
- `POST /` — create (201)
- `GET /{id}` — detail
- `PATCH /{id}` — update (expectedRowVersion in body)

**AdminAnimationSceneController:**
- `GET /` — list (page/size/sort/q/templateId/eventId/status)
- `POST /` — create (201)
- `GET /{id}` — detail
- `PATCH /{id}` — update title/eventId
- `PUT /{id}/draft` — replace draft_json
- `POST /{id}/duplicate` — duplicate scene
- `POST /{id}/validate` — readiness probe (always 200)
- `POST /{id}/publish` — transactional publish
- `POST /{id}/archive` — archive

**AdminAnimationSceneVersionController:**
- `GET /` — list versions
- `GET /{versionId}` — full snapshot detail
- `GET /current` — current published version

### Step 8: Exception handling

Register `AnimationValidationException` → 422 `ANIMATION_SCHEMA_INVALID` with `details.errors[]`.
`AnimationSceneNotFoundException` → 404 `SCENE_NOT_FOUND`.
`AnimationTemplateNotFoundException` → 404 `TEMPLATE_NOT_FOUND`.
Check if there's a global `@ExceptionHandler`/`@ControllerAdvice` — if yes, add handlers there.

### Step 9: Tests

- `AnimationManifestValidatorTest` — each of the 15 checks, valid manifest passes.
- `AnimationTemplateIT` — CRUD, authz (401/403), duplicate code → 409.
- `AnimationScenePublishIT` — publish creates immutable version, optimistic lock → 409, invalid manifest → 422, concurrent publish serializes.

## Todo List

- [ ] V14 Flyway migration file created and compiles
- [ ] `AnimationTemplate` entity + repository
- [ ] `AnimationScene` entity + repository
- [ ] `AnimationSceneVersion` entity + repository
- [ ] `AnimationSceneAssetRef` entity + repository
- [ ] `AnimationSceneStatus` enum
- [ ] Domain exceptions
- [ ] `AnimationManifestSchema` constants
- [ ] `AnimationManifestValidator` — all 15 checks
- [ ] `AnimationTemplateService` — CRUD
- [ ] `AnimationSceneService` — CRUD + duplicate + archive + validate
- [ ] `AnimationScenePublishService` — transactional publish
- [ ] `AdminAnimationTemplateController`
- [ ] `AdminAnimationSceneController`
- [ ] `AdminAnimationSceneVersionController`
- [ ] All DTOs
- [ ] `AnimationManifestValidatorTest` — unit tests
- [ ] `AnimationTemplateIT` — integration tests
- [ ] `AnimationScenePublishIT` — integration tests
- [ ] `./mvnw.cmd test` passes

## Success Criteria

- V14 migration runs clean on existing DB (PostgreSQL 16, Testcontainers).
- `POST /api/v1/admin/animation-templates` creates template → 201.
- `POST /api/v1/admin/animation-scenes` creates scene → 201.
- `PUT /{id}/draft` saves manifest draft.
- `POST /{id}/publish` creates immutable version → correct version_no, checksum, asset_refs.
- `POST /{id}/validate` returns `{ready, errors[], warnings[]}` — always 200.
- `PATCH`/`PUT` with stale `expectedRowVersion` → 409 `OPTIMISTIC_LOCK_CONFLICT`.
- Anonymous → 401; LEARNER → 403; CONTENT_ADMIN → 200.
- Invalid manifest → 422 with `details.errors[]` {path, code, message}.
- `mvnw.cmd test` — all tests pass including new ITs.

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Flyway migration fails on existing data | V14 only creates new tables — no ALTER on existing tables (except none). Test with Testcontainers. |
| Validator too strict blocks valid manifests | Validate against the 3 known seed manifests (Bạch Đằng, Hai Bà Trưng, Lý Thái Tổ) — write test cases from their actual data. |
| Exception handler not found | Check `common/` package for existing `@ControllerAdvice`; if missing, create one in `animation/api/`. |
| JSONB String vs JsonNode type mismatch | Follow `Lesson.java` exactly — `String` field with `@JdbcTypeCode(SqlTypes.JSON)`, parse with ObjectMapper at service layer. |

## Security Considerations

- All endpoints under `/api/v1/admin/**` → CONTENT_ADMIN only (enforced by existing Spring Security config).
- Manifest JSON bounded: max 500KB, max 20 depth, max 200 objects/50 steps/50 assets.
- Asset refs validated at publish — only ACTIVE assets can be referenced.
- No executable code in manifest — whitelisted object types, easing functions, effect types only.
- `manifest_checksum` prevents tampering — SHA-256 of canonical JSON.
- Draft manifest never exposed to learners (learner projection strips admin fields).

## Next Steps

→ Phase 2: Extend `ReadValidator` to accept `animationSceneId`/`animationSceneVersionId`/`playbackMode`; extend `SnapshotBuilder` to embed manifest + pin assets; build Flutter runtime DTOs + renderers.
