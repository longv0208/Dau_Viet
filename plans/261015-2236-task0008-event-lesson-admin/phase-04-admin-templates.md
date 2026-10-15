# Phase 04 — Lesson Template read endpoints

## Context links

- `tasks/TASK-0008/task.json` AC-3
- `dau-viet-backend/src/main/resources/db/migration/V3__authoring_publishing_evidence_assets.sql` — `lesson_templates` table (`code`, `name`, `description`, `schema_version`, `preset_json`, `enabled`)

## Overview

- Priority: P2 (small surface; needed by admin UI to pick template when creating lesson).
- Status: pending
- Two read-only admin endpoints. No create/update/delete — brief explicitly forbids template editing.

## Key insights

- Templates are seeded via migrations or admin SQL — no public API to mutate. Read surface is small.
- `enabled=false` templates are hidden from list endpoint; `findById` returns 404 for both missing AND disabled (don't leak existence of disabled templates — same convention as public events).

## Requirements

- `GET /api/v1/admin/lesson-templates` — list enabled templates (`{id, code, name, description, schemaVersion}`). No pagination needed for MVP (few templates expected). If list grows, switch to `PageResponse` later (YAGNI).
- `GET /api/v1/admin/lesson-templates/{id}` — detail incl. `presetJson` (returned as parsed JSON, not string) for the admin UI to render defaults.

## Architecture

```
com.dauviet.lesson.api/
├── AdminLessonTemplateController.java
├── dto/
│   ├── AdminLessonTemplateSummaryDto.java    { id, code, name, description, schemaVersion }
│   └── AdminLessonTemplateDetailDto.java     { + presetJson (JsonNode) }
└── mapper/AdminLessonTemplateMapper.java

com.dauviet.lesson.application/
└── LessonTemplateService.java                (read-only; delegates to repo)
```

## Related code files

### Create

- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/AdminLessonTemplateController.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/dto/AdminLessonTemplateSummaryDto.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/dto/AdminLessonTemplateDetailDto.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/mapper/AdminLessonTemplateMapper.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LessonTemplateService.java`

### Modify

- None.

### Delete

- None.

## Implementation steps

1. DTOs (records). `presetJson` typed `JsonNode` — service deserialises stored `String` via `ObjectMapper.readTree`.
2. `LessonTemplateService`:
   - `listEnabled()` — `repo.findAllByEnabledTrue()` → summary list.
   - `getById(id)` — `repo.findById` filter `enabled=true` → detail or `TemplateNotFoundException`.
3. `AdminLessonTemplateController` — two GET endpoints under `/api/v1/admin/lesson-templates`.
4. `mvnw -q test-compile`.

## Todo

- [ ] DTOs (2 records).
- [ ] Mapper.
- [ ] Service.
- [ ] Controller.
- [ ] Compile clean.

## Success criteria

- `GET /admin/lesson-templates` returns 200 list under `CONTENT_ADMIN`, 401 anonymous, 403 learner.
- Disabled template `GET /{id}` → 404 `TEMPLATE_NOT_FOUND`.

## Risk assessment

- Low. Read-only surface; only sharp edge is `presetJson` deserialisation failure (corrupt seed data) → 500 is acceptable, schema CHECK already ensures object type.

## Security considerations

- Preset content is admin-only — never exposed publicly. Mapper does not include it in summary DTO.

## Next steps

- Phase 05 ITs cover this surface.
