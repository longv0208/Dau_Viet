# Phase 03 — Admin Lessons endpoints + draft editing

## Context links

- `tasks/TASK-0008/task.json` AC-2, AC-5
- `dau-viet-backend/src/main/resources/db/migration/V3__authoring_publishing_evidence_assets.sql` — `lessons` schema (`draft_json`, `objectives_json`, `current_version_id`, `row_version`, status CHECK)
- `docs/LEARNING_ENGINE_DESIGN.md` §9 — publish validation rules (informational; publish endpoint is TASK-0009, out of scope here)
- `docs/API_SPEC.md` §3 — draft full-document `PUT` contract, `expectedDraftRevision` field name

## Overview

- Priority: P1
- Status: pending
- Implements `/api/v1/admin/lessons`: create, list (paginated + filter), detail, update metadata, update draft (JSONB full-document replace), archive. No publish (deferred to TASK-0009), no DELETE.

## Key insights

- `Lesson` entity exposes `draftJson` as `String` (JSONB). Draft update endpoint accepts `JsonNode`, validates it's a JSON object, then serialises back to `String` for storage.
- `expectedDraftRevision` in API_SPEC maps to `row_version` — client sends the version it last saw; service compares to current; mismatch → 409 `OPTIMISTIC_LOCK_CONFLICT`. Implementation: include `expectedRowVersion` in `UpdateLessonDraftRequest`; service does `if (lesson.getRowVersion() != req.expectedRowVersion()) throw new OptimisticLockConflictException()`. Or simpler: rely on JPA `@Version` and have client send `If-Match` header — **decision:** keep body-based `expectedRowVersion` for symmetry with API_SPEC; on mismatch throw `ObjectOptimisticLockingFailureException`-compatible exception → mapped 409.
- Creating a lesson does NOT auto-create a `lesson_versions` row. `current_version_id` stays `null`. Status stays `DRAFT` until TASK-0009 publish flow exists.
- `archive` transitions `DRAFT|PUBLISHED → ARCHIVED`. Archiving a `PUBLISHED` lesson does NOT modify the existing `lesson_versions` row (immutable) — it only flips `lessons.status`. Attempts already running keep working (per DATABASE_DESIGN invariants — learner policy is TASK-0009+).
- `current_version_id` is set only by the future publish action; never exposed writable in this phase's DTOs.
- Lesson status model mirrors event status (DRAFT/PUBLISHED/ARCHIVED — same CHECK constraint).
- Lesson-Event FK: `create` requires `eventId` referencing an existing `historical_events.id` — any status allowed (admin may draft lesson against draft event). Service validates via `HistoricalEventRepository.findById` → 404 `EVENT_NOT_FOUND` if absent.
- Lesson-Template FK: `templateId` must exist AND `enabled=true`. Missing → 404 `TEMPLATE_NOT_FOUND`; disabled → 422 `TEMPLATE_DISABLED`.
- Draft JSON validation (minimal — full publish validation is TASK-0009):
  - Payload must be a JSON object (`jsonb_typeof = 'object'` already enforced by CHECK; service re-validates to give better error code).
  - If `draft.schemaVersion` present, must be `>= 1` integer.
  - If `draft.stages` present, must be an array; each stage must have `id` (string) and `type` (string). Keep validation light — full schema enforcement lives in publish.
- `objectives_json` — array column; request sends `List<String> objectives`; service serialises to JSON array; empty list allowed; `null` on update = leave unchanged.

## Requirements

- `POST /api/v1/admin/lessons` — body `{eventId @NotNull UUID, templateId @NotNull UUID, title @NotBlank, centralQuestion @NotBlank, objectives? List<String>, draft? JsonNode}` → 201 detail. Initial `status=DRAFT`. Validates event exists + template enabled.
- `GET /api/v1/admin/lessons?page=&size=&sort=&status=&eventId=&q=` — paginated list. `q` searches `title` + `centralQuestion` (ilike).
- `GET /api/v1/admin/lessons/{id}` — returns detail incl. `draft`, `objectives`, `currentVersionId`, `rowVersion`.
- `PATCH /api/v1/admin/lessons/{id}` — partial update of `{title?, centralQuestion?, objectives?, eventId?, templateId?}`. Changing `eventId`/`templateId` allowed only when `status=DRAFT` (rebinding on published lesson is unsafe). Returns detail.
- `PUT /api/v1/admin/lessons/{id}/draft` — body `{draft JsonNode @NotNull, expectedRowVersion Long @NotNull}`. Validates JSON is object + minimal schema. Returns updated detail. Rejects when `status=ARCHIVED` (no point editing archived content). On `PUBLISHED` lesson, draft edit is allowed (per brief: "preserve the current published version when editing a draft" — draft diverges from snapshot, snapshot unchanged).
- `POST /api/v1/admin/lessons/{id}/archive` — `DRAFT|PUBLISHED → ARCHIVED`. Archived lessons are excluded from public/learner surfaces (handled by TASK-0009 publish pipeline).

## Architecture

```
com.dauviet.lesson/
├── api/
│   ├── AdminLessonController.java
│   ├── dto/
│   │   ├── AdminLessonCreateRequest.java
│   │   ├── AdminLessonUpdateRequest.java
│   │   ├── AdminLessonDraftUpdateRequest.java   { draft, expectedRowVersion }
│   │   ├── AdminLessonSummaryDto.java           { id, eventId, title, status, updatedAt, rowVersion }
│   │   ├── AdminLessonDetailDto.java            { + centralQuestion, objectives, draft, currentVersionId, createdAt, templateId }
│   │   └── ...
│   └── mapper/
│       └── AdminLessonMapper.java
├── application/
│   └── LessonService.java                       (admin-facing service; name kept simple — only one LessonService)
└── (domain + infrastructure from phase-01)
```

`LessonService` injects `LessonRepository`, `LessonVersionRepository` (for `currentVersionId` resolution when needed), `HistoricalEventRepository`, `LessonTemplateRepository`, `ObjectMapper`.

## Related code files

### Create

- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/AdminLessonController.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/dto/AdminLessonCreateRequest.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/dto/AdminLessonUpdateRequest.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/dto/AdminLessonDraftUpdateRequest.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/dto/AdminLessonSummaryDto.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/dto/AdminLessonDetailDto.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/mapper/AdminLessonMapper.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LessonService.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/DraftValidator.java` — minimal schema check (separate class for testability, <80 lines).

### Modify

- None beyond phase-01 outputs.

### Delete

- None.

## Implementation steps

1. DTOs (records). `draft` field type `JsonNode` (Jackson binds raw JSON, no string double-encoding).
2. `DraftValidator`:
   - `void validate(JsonNode draft)` → throws `DraftSchemaInvalidException` on structural errors.
   - Rules: `draft.isObject()` required; `draft.has("schemaVersion")` → must be `IntNode`/`NumberNode` `>=1`; `draft.has("stages")` → must be `ArrayNode`, each element object with `id` + `type` text fields.
   - ~50 lines, single responsibility.
3. `LessonService`:
   - `create(req)` — find event (404 if missing), find template (404 missing / 422 disabled), build entity `id=UUID.randomUUID()`, `status=DRAFT`, `objectivesJson` = serialised list or `'[]'`, `draftJson` = serialised draft or `'{}'`, `createdBy`/`updatedBy` = current admin user id (from `SecurityContextHolder` → `Jwt.getSubject()` → `UUID.fromString`); save.
   - `list(...)` — `JpaSpecificationExecutor` spec combining `status`, `eventId`, `q` (title + centralQuestion ilike).
   - `getById`, `update`, `updateDraft`, `archive` mirroring phase-02 patterns.
   - `updateDraft`: load; check `status != ARCHIVED`; check `expectedRowVersion == lesson.getRowVersion()` → `ObjectOptimisticLockingFailureException` if not; `DraftValidator.validate(draft)`; `lesson.setDraftJson(om.writeValueAsString(draft))`; save — `@Version` bumps `row_version` so concurrent second writer with stale `expectedRowVersion` is rejected at the service check AND/OR by JPA optimistic lock on flush.
   - `archive`: `DRAFT|PUBLISHED → ARCHIVED`. If `ARCHIVED` already → 409 `INVALID_STATUS_TRANSITION`.
4. `AdminLessonController` — six endpoints, sort whitelist `{"title","updatedAt","createdAt"}`.
5. Helper `currentUserId()` — extract from `SecurityContextHolder.getContext().getAuthentication().getPrincipal()` cast to `Jwt`, parse `getSubject()` → `UUID`. Place in `com.dauviet.common.security` or duplicate as private method (KISS: private static in service is fine; if two+ services need it, lift to utility).

## Todo

- [ ] DTO records (6 files).
- [ ] `AdminLessonMapper`.
- [ ] `DraftValidator` (minimal).
- [ ] `LessonService` — six operations.
- [ ] `AdminLessonController`.
- [ ] `mvnw -q test-compile` clean.

## Success criteria

- All endpoints 200/201 under `CONTENT_ADMIN`; 401 anonymous; 403 learner.
- `POST` with missing `eventId` → 404 `EVENT_NOT_FOUND`; missing `templateId` → 404 `TEMPLATE_NOT_FOUND`; disabled template → 422 `TEMPLATE_DISABLED`.
- `PUT draft` with stale `expectedRowVersion` → 409 `OPTIMISTIC_LOCK_CONFLICT`.
- `PUT draft` with non-object JSON or invalid `schemaVersion` → 422 `DRAFT_SCHEMA_INVALID`.
- `PATCH` on `ARCHIVED` lesson → 409 `INVALID_STATUS_TRANSITION` (decide and document).
- `lesson_versions` rows never mutated (trigger guards anyway — no test for it here; FlywayMigrationIT already covers).

## Risk assessment

- **Risk:** `JsonNode` field in record + `@NotNull` — Jackson accepts `null` literal which becomes `NullNode` not `null`. Mitigation: `@NotNull` + explicit `!draft.isNull() && draft.isObject()` check in validator.
- **Risk:** `objectives` serialised as JSON array of strings — caller may send objects. Document `List<String>` type; validation rejects non-string via type mismatch.
- **Risk:** service-check `expectedRowVersion` is racy with concurrent writers (TOCTOU between read and write). Mitigation: rely on JPA `@Version` for actual write-time protection; `expectedRowVersion` is a friendly pre-check. Both layers exist.
- **Risk:** Optimistic lock exceptions from `JpaRepository.save` may surface as `ObjectOptimisticLockingFailureException` or `OptimisticLockException` (jakarta). Handler catches the Spring `ObjectOptimisticLockingFailureException` superclass — covers both.

## Security considerations

- Draft content is admin-only — never returned by public endpoints (no public lesson controller exists yet).
- `createdBy`/`updatedBy` come from JWT `sub` (server-derived), never from request body.

## Next steps

- Phase 04 (templates read-only) is independent — can run in parallel with phase-03 if separate writers; otherwise sequential.
