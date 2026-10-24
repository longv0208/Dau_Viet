---
title: "Phase 01 — V19 migration + backend model"
description: "Create V19 Flyway migration (template row + 2 HTML tables + immutability trigger) and JPA entities/repos."
status: pending
priority: P1
effort: 2h
---

# Phase 01 — V19 Migration + Backend Model

## Context Links

- Audit: `plans/reports/researcher-261024-1623-backend-animation-audit.md` (§1, §3, §10)
- Reference DDL: `dau-viet-backend/src/main/resources/db/migration/V14__animation_engine.sql` (immutability trigger pattern)
- Checksum recipe: `V15__animation_seed.sql` (`encode(digest(...,'sha256'),'hex')`)
- Manifest checksum VARCHAR(64): `V18__animation_scene_versions_checksum_varchar.sql`
- Domain: `com.dauviet.animation.domain.*`, repos under `infrastructure/persistence/`
- `application.yml` currently has `multipart.max-file-size=10MB` — will be raised in Phase 02.

## Overview

- Priority: P1 — blocks every other phase.
- Status: pending.
- Brief: schema foundation + JPA entities so later phases can persist/serve HTML.

## Key Insights

- `animation_scene_versions` already enforces immutability via `trg_animation_scene_versions_immutable`. Mirror pattern for `animation_scene_version_html`.
- `manifest_checksum` was widened to VARCHAR(64) in V18 → use `VARCHAR(64)` for `sha256` columns.
- `animation_templates` row requires `capabilities_json`/`default_config_json` JSONB — keep minimal.
- `animation_scene_html` is keyed by `scene_id` (1:1 draft, mutable), `animation_scene_version_html` by `version_id` (1:1 published, immutable).

## Requirements

### Functional
- Template `code='html-webview'`, `renderer_code='HTML_WEBVIEW'`, `renderer_version=1`, `schema_version=2`, `enabled=true`, `capabilities_json='{"html":true}'`, `default_config_json='{"schemaVersion":2,"rendererCode":"HTML_WEBVIEW","rendererVersion":1}'`.
- `animation_scene_html`: `scene_id UUID PK FK→animation_scenes(id) ON DELETE CASCADE`, `content TEXT NOT NULL`, `sha256 VARCHAR(64) NOT NULL`, `size_bytes BIGINT NOT NULL`, `original_filename VARCHAR(255)`, `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`.
- `animation_scene_version_html`: `version_id UUID PK FK→animation_scene_versions(id) ON DELETE RESTRICT`, `content TEXT NOT NULL`, `sha256 VARCHAR(64) NOT NULL`, `size_bytes BIGINT NOT NULL`, `original_filename VARCHAR(255)`.
- Immutability trigger `trg_animation_scene_version_html_immutable` BEFORE UPDATE/DELETE on `animation_scene_version_html` reusing `prevent_animation_scene_version_mutation()` (or a clone with renamed message — reuse is fine since message text is generic).

### Non-functional
- ON DELETE CASCADE on draft keeps orphaned drafts impossible.
- ON DELETE RESTRICT on version html prevents version deletion while html exists (consistent with asset refs).

## Architecture

```
animation_templates (V19 INSERT)
  └── animation_scenes (existing)
        ├── draft_json (minimal manifest)
        └── animation_scene_html  (V19, 1:1 mutable draft)
        └── animation_scene_versions (existing)
              └── animation_scene_version_html (V19, 1:1 immutable)
```

## Related Code Files

### Create
- `dau-viet-backend/src/main/resources/db/migration/V19__html_webview_animation.sql`
- `dau-viet-backend/src/main/java/com/dauviet/animation/domain/AnimationSceneHtml.java`
- `dau-viet-backend/src/main/java/com/dauviet/animation/domain/AnimationSceneVersionHtml.java`
- `dau-viet-backend/src/main/java/com/dauviet/animation/infrastructure/persistence/AnimationSceneHtmlRepository.java`
- `dau-viet-backend/src/main/java/com/dauviet/animation/infrastructure/persistence/AnimationSceneVersionHtmlRepository.java`

### Modify
- None in this phase (validator/service changes live in Phase 02).

## Implementation Steps

1. Write `V19__html_webview_animation.sql`:
   - `INSERT INTO animation_templates (id, code, name, description, renderer_code, renderer_version, schema_version, capabilities_json, default_config_json, enabled) VALUES (gen_random_uuid(), 'html-webview', 'Hoạt họa HTML', 'Self-contained HTML rendered in app WebView', 'HTML_WEBVIEW', 1, 2, '{"html":true}'::jsonb, '{"schemaVersion":2,"rendererCode":"HTML_WEBVIEW","rendererVersion":1}'::jsonb, TRUE);`
   - `CREATE TABLE animation_scene_html (...)` with PK/FK/CASCADE.
   - `CREATE TABLE animation_scene_version_html (...)` with PK/FK/RESTRICT.
   - `CREATE TRIGGER trg_animation_scene_version_html_immutable BEFORE UPDATE OR DELETE ON animation_scene_version_html FOR EACH ROW EXECUTE FUNCTION prevent_animation_scene_version_mutation();`
2. JPA entities:
   - `AnimationSceneHtml` — `@Entity @Table(name="animation_scene_html")`, `@Id UUID sceneId`, `@Lob @Column(name="content") String content`, `sha256`, `sizeBytes`, `originalFilename`, `updatedAt`. No `@Version` (mutated via `save`).
   - `AnimationSceneVersionHtml` — same fields minus `updatedAt`; mark all `@Column(updatable=false)`; `@Id UUID versionId`.
3. Repos:
   - `AnimationSceneHtmlRepository extends JpaRepository<AnimationSceneHtml, UUID>` (findById suffices).
   - `AnimationSceneVersionHtmlRepository extends JpaRepository<AnimationSceneVersionHtml, UUID>` (findById suffices).

## Todo

- [ ] Write V19 migration SQL.
- [ ] Create `AnimationSceneHtml` entity.
- [ ] Create `AnimationSceneVersionHtml` entity.
- [ ] Create `AnimationSceneHtmlRepository`.
- [ ] Create `AnimationSceneVersionHtmlRepository`.
- [ ] `./mvnw -pl dau-viet-backend flyway:info` (or test via Testcontainers / local psql) — confirm V19 applied cleanly.
- [ ] `./mvnw -pl dau-viet-backend compile` — entities build under `ddl-auto=validate`.

## Success Criteria

- `mvn -pl dau-viet-backend spring-boot:run` starts cleanly; `flyway_schema_history` lists V19.
- `\d animation_scene_html` shows PK+FK CASCADE; `\d animation_scene_version_html` shows PK+FK RESTRICT + trigger.
- Template `html-webview` selectable via `GET /api/v1/admin/animation-templates?enabled=true`.
- `UPDATE animation_scene_version_html SET content='x'` raises exception.

## Risks

- `prevent_animation_scene_version_mutation()` message mentions `animation_scene_versions` — accept generic message OR create clone `prevent_animation_scene_version_html_mutation()`. Choose clone for clarity (small dup is fine; DRY rule is not violated because error messages need distinct text).
- `TEXT` column for 15 MB — Postgres TOAST handles; no `bytea` needed since charset is UTF-8.

## Security Considerations

- HTML content stored as `TEXT`, never served from this phase — endpoint security lives in Phase 02.
- No external refs allowed — enforcement is application-layer (Phase 02 validator).
