# Phase 01 — Shared plumbing

## Context links

- `tasks/TASK-0008/task.json` AC-5, AC-7
- `dau-viet-backend/src/main/resources/db/migration/V1__create_historical_events.sql` (no `row_version`)
- `dau-viet-backend/src/main/resources/db/migration/V3__authoring_publishing_evidence_assets.sql` (`lessons.row_version` present, `draft_json` present, immutable trigger on `lesson_versions`)
- `dau-viet-backend/src/main/java/com/dauviet/common/api/PageResponse.java` (reuse as-is)
- `dau-viet-backend/src/main/java/com/dauviet/common/error/ErrorCode.java` + `GlobalExceptionHandler.java`
- `dau-viet-backend/src/main/java/com/dauviet/user/domain/User.java` (`@Version` reference pattern)

## Overview

- Priority: P1 — gates all later phases.
- Status: pending.
- Adds V5 Flyway migration (`historical_events.row_version`), `@Version` to `HistoricalEvent`, new entities `Lesson`, `LessonTemplate`, `LessonVersion` (read+insert only — never UPDATE/DELETE on `lesson_versions`), repositories, and new `ErrorCode` values.

## Key insights

- `lessons.row_version` already in V3 → map directly via `@Version`.
- `historical_events` has no version column → V5 required, single-column add, zero data risk.
- `lesson_versions` has `BEFORE UPDATE OR DELETE` trigger — JPA entity must be read+insert only. No `@Version` here (immutable snapshot row).
- `lessons.current_version_id` uses composite FK `(current_version_id, id) → lesson_versions(id, lesson_id)` — JPA mapping must use `@ManyToOne` on `Lesson.currentVersion` plus `insertable=false,updatable=false` on `lesson_id` join, OR simpler: keep `currentVersionId` as a plain `UUID` column and resolve via `LessonVersionRepository` when needed. **Choose the plain `UUID` approach** — less magic, no risk of cross-lesson corruption.
- `draft_json`, `objectives_json`, `preset_json`, `snapshot_json` are `JSONB` — map via `@JdbcTypeCode(SqlTypes.JSON)` + `String` column storage (KISS — no `JsonNode`/`Map` typed wrapper for MVP; service validates JSON shape at write boundary via Jackson `ObjectMapper.readTree`).
- `tags` is `text[]` — already mapped on `HistoricalEvent` via `JdbcTypeCode(SqlTypes.ARRAY)`. No change.

## Requirements

- V5 migration applies cleanly on fresh Postgres AND on already-migrated V4 DB.
- `HistoricalEvent.rowVersion` populated by Hibernate on update; concurrency test in phase-05 relies on this.
- New ErrorCode values:
  - `INVALID_STATUS_TRANSITION` → 409
  - `EVENT_IN_USE` → 409
  - `EVENT_NOT_FOUND` (already exists)
  - `LESSON_NOT_FOUND` → 404
  - `TEMPLATE_NOT_FOUND` → 404
  - `TEMPLATE_DISABLED` → 422
  - `LESSON_VERSION_IMMUTABLE` → 409 (defensive; trigger should fire first)
  - `OPTIMISTIC_LOCK_CONFLICT` → 409 (mapped from `ObjectOptimisticLockingFailureException`)
  - `DRAFT_SCHEMA_INVALID` → 422
- Repository methods needed:
  - `HistoricalEventRepository`: existing + add `Page<HistoricalEvent> findByStatusInAndTitleContainingIgnoreCaseOrSlugContainingIgnoreCase(...)` — simpler: use `JpaSpecificationExecutor` for `q`/`status` filter combo (cleaner than 4 derived methods).
  - `LessonRepository`: extend `JpaRepository` + `JpaSpecificationExecutor`; methods `findByEventId(UUID)`, `existsByEventIdAndStatusNot(UUID, LessonStatus)`.
  - `LessonTemplateRepository`: `findByCode`, `findAllByEnabledTrue`, `findById`.
  - `LessonVersionRepository`: `findByLessonIdAndVersionNo`, `findTopByLessonIdOrderByVersionNoDesc`, `findById` (inherited). **Never** expose save for update — provide `save` for INSERT only via JPA (we won't add a `updateSnapshot` method).

## Architecture

```
com.dauviet.lesson/
├── domain/
│   ├── Lesson.java                  (entity, @Version on row_version)
│   ├── LessonStatus.java            (DRAFT, PUBLISHED, ARCHIVED)
│   ├── LessonTemplate.java          (entity, read-only use)
│   ├── LessonVersion.java           (entity, no @Version — trigger guards)
│   ├── LessonNotFoundException.java
│   ├── TemplateNotFoundException.java
│   ├── TemplateDisabledException.java
│   ├── InvalidStatusTransitionException.java
│   ├── EventInUseException.java
│   └── DraftSchemaInvalidException.java
├── application/
│   ├── LessonService.java           (admin write/read; uses repos)
│   └── LessonTemplateService.java   (read-only)
├── infrastructure/persistence/
│   ├── LessonRepository.java
│   ├── LessonVersionRepository.java
│   └── LessonTemplateRepository.java
└── api/                             (populated in phases 03/04)
```

For admin event endpoints, classes live under `com.dauviet.historicalevent.admin` (sub-package, not new module) so existing `historicalevent` module owns all event code. Pattern: `admin/AdminEventController`, `admin/AdminEventService`, `admin/dto/*`, `admin/mapper/*`.

## Related code files

### Modify

- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/domain/HistoricalEvent.java` — add `@Version` + `rowVersion` field, getter.
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/infrastructure/persistence/HistoricalEventRepository.java` — extend `JpaSpecificationExecutor<HistoricalEvent>`.
- `dau-viet-backend/src/main/java/com/dauviet/common/error/ErrorCode.java` — add new enum constants.
- `dau-viet-backend/src/main/java/com/dauviet/common/error/GlobalExceptionHandler.java` — add `@ExceptionHandler` methods for new domain exceptions + `ObjectOptimisticLockingFailureException` → 409 `OPTIMISTIC_LOCK_CONFLICT`.

### Create

- `dau-viet-backend/src/main/resources/db/migration/V5__add_historical_events_row_version.sql`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/Lesson.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/LessonStatus.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/LessonTemplate.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/LessonVersion.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/LessonNotFoundException.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/TemplateNotFoundException.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/TemplateDisabledException.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/InvalidStatusTransitionException.java` (shared by event + lesson)
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/EventInUseException.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/DraftSchemaInvalidException.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/infrastructure/persistence/LessonRepository.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/infrastructure/persistence/LessonVersionRepository.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/infrastructure/persistence/LessonTemplateRepository.java`

### Delete

- None.

## Implementation steps

1. Write `V5__add_historical_events_row_version.sql`:
   ```sql
   ALTER TABLE historical_events
       ADD COLUMN row_version BIGINT NOT NULL DEFAULT 0;
   ```
2. Add `@Version private Long rowVersion` + getter to `HistoricalEvent`. No setter.
3. Add `EventStatus`-mirroring `LessonStatus` enum under `com.dauviet.lesson.domain`.
4. Write `Lesson` entity mapping `lessons` table: `id`, `eventId`, `templateId` as plain `UUID` columns (no `@ManyToOne` — keeps writes simple and avoids lazy-load pitfalls across module boundaries); `title`, `centralQuestion`, `objectivesJson` (`String` + `@JdbcTypeCode(SqlTypes.JSON)`), `draftJson` (same), `status`, `currentVersionId` (`UUID`), `createdBy`, `updatedBy` (`UUID`), `createdAt`, `updatedAt`, `@Version rowVersion`.
5. Write `LessonTemplate` entity: `id`, `code`, `name`, `description`, `schemaVersion` (`Integer`), `presetJson` (`String` + JSON), `enabled` (`Boolean`), `createdAt`, `updatedAt`. Read-only entity.
6. Write `LessonVersion` entity: `id`, `lessonId` (`UUID`), `versionNo` (`Integer`), `schemaVersion` (`Integer`), `snapshotJson` (`String` + JSON), `publishedAt` (`Instant`), `publishedBy` (`UUID`). **No `@Version`, no update methods** — JavaDoc note: "immutable at DB layer".
7. Write repositories (interfaces only).
8. Extend `ErrorCode` enum.
9. Extend `GlobalExceptionHandler`:
   - `InvalidStatusTransitionException` → 409 `INVALID_STATUS_TRANSITION`
   - `EventInUseException` → 409 `EVENT_IN_USE`
   - `LessonNotFoundException` → 404 `LESSON_NOT_FOUND`
   - `TemplateNotFoundException` → 404 `TEMPLATE_NOT_FOUND`
   - `TemplateDisabledException` → 422 `TEMPLATE_DISABLED`
   - `DraftSchemaInvalidException` → 422 `DRAFT_SCHEMA_INVALID`
   - `ObjectOptimisticLockingFailureException` → 409 `OPTIMISTIC_LOCK_CONFLICT`
10. Run `mvnw -q test-compile`. Then `mvnw -Dtest=FlywayMigrationIT verify` — confirm V5 applied (extend `flywayV2ToV4Applied` or add `flywayV5Applied` test in phase-05).

## Todo

- [ ] V5 migration file written and applied by FlywayMigrationIT.
- [ ] `@Version` on `HistoricalEvent` (field + getter only).
- [ ] `Lesson`, `LessonTemplate`, `LessonVersion` entities.
- [ ] `LessonStatus` enum (DRAFT/PUBLISHED/ARCHIVED).
- [ ] Domain exceptions (6 new).
- [ ] 3 repository interfaces.
- [ ] `ErrorCode` extended.
- [ ] `GlobalExceptionHandler` handlers added.
- [ ] `mvnw -q test-compile` clean.

## Success criteria

- `mvnw test-compile` exits 0.
- `FlywayMigrationIT` (extended) confirms V5 in `flyway_schema_history`.
- No changes to `SecurityConfig` needed — `/api/v1/admin/**` already covers all new admin paths.

## Risk assessment

- **Risk:** `historical_events` rows that exist before V5 get `row_version=0`, fine — Hibernate treats as initial.
- **Risk:** `@JdbcTypeCode(SqlTypes.JSON)` on `String` requires Hibernate 6 — already on Spring Boot 3.4 (Hibernate 6.6), safe.
- **Risk:** `Lesson` uses plain `UUID` for `eventId`/`templateId` — service layer must validate existence manually. Mitigation: `LessonService.create` always calls `HistoricalEventRepository.findById` and `LessonTemplateRepository.findById` before insert.

## Security considerations

- All new code runs only under `/api/v1/admin/**` (enforced upstream by existing SecurityConfig) or internal services.
- `draft_json` may contain author notes — never serialised to public/learner DTOs. Mapper layer is the boundary.

## Next steps

- Phase 02 wires `AdminEventController` + `AdminEventService` on top of this plumbing.
