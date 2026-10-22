# Phase 01 — Backend domain + Flyway migration

## Context links

- `docs/DATABASE_DESIGN.md` sections 3-5 (table conventions, migration status)
- `dau-viet-backend/src/main/resources/db/migration/V7__seed_default_lesson_template.sql` (latest migration — next is V8)
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/domain/HistoricalEvent.java` (entity conventions: UUID id, `@Version row_version`, `EventStatus` enum)
- `dau-viet-backend/src/main/java/com/dauviet/lesson/domain/Lesson.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/domain/LearnerAttempt.java`

## Overview

- Priority: P0 (blocks everything else)
- Add `map_locations` table + JPA entity + repository. Purely additive; no changes to existing tables.

## Requirements

- `map_locations` rows belong to a `historical_events` parent; optionally link a `lessons` row as `unlock_lesson_id` (nullable).
- Coordinate validation at DB level (CHECK) AND service level (Bean Validation on admin request DTOs in phase 03).
- `unlock_lesson_id` must reference a lesson that belongs to the SAME event — enforced in service (DB CHECK can't span tables; FK + service check).
- `display_order` integer for deterministic ordering; `active` boolean for admin soft-toggle.
- Optimistic locking via `row_version` (same convention as `historical_events`, `evidences`).
- No geocoding; admin supplies coords. No seed data with coordinates.

## Schema — `V8__map_locations.sql`

```sql
CREATE TABLE map_locations (
    id UUID PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES historical_events(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    unlock_lesson_id UUID REFERENCES lessons(id),
    display_order INTEGER NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_map_lat CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_map_lng CHECK (longitude BETWEEN -180 AND 180)
);
CREATE INDEX idx_map_locations_event ON map_locations(event_id, display_order);
CREATE INDEX idx_map_locations_unlock_lesson ON map_locations(unlock_lesson_id);
```

## Files to create

- `dau-viet-backend/src/main/resources/db/migration/V8__map_locations.sql`
- `dau-viet-backend/src/main/java/com/dauviet/map/domain/MapLocation.java` — `@Entity` on `map_locations`; fields above; `MapLocationStatus` enum NOT needed (active bool).
- `dau-viet-backend/src/main/java/com/dauviet/map/infrastructure/persistence/MapLocationRepository.java` — `JpaRepository<MapLocation, UUID>`:
  - `List<MapLocation> findByEventIdInAndActiveTrueOrderByDisplayOrderAsc(Collection<UUID> eventIds)`
  - `List<MapLocation> findByEventIdOrderByDisplayOrderAsc(UUID eventId)` (admin)
  - `Optional<MapLocation> findByIdAndActiveTrue(UUID id)`
- `dau-viet-backend/src/main/java/com/dauviet/map/domain/MapLocationNotFoundException.java`
- `dau-viet-backend/src/main/java/com/dauviet/map/domain/UnlockLessonMismatchException.java` — when `unlockLesson.eventId != location.eventId` → 422.

New package `com.dauviet.map` keeps event package uncluttered; mirrors `com.dauviet.learning` structure (domain / application / api / infrastructure.persistence).

## Entity conventions to follow

- `@Id UUID id`, assigned in factory (`UUID.randomUUID()`), `updatable=false`
- `@CreationTimestamp createdAt`, `@UpdateTimestamp updatedAt`
- `@Version Long rowVersion`
- Columns snake_case via `@Column(name=...)`
- Factory `MapLocation.create(...)` + `update(...)` mutator
- Getter-only style like `HistoricalEvent` (no Lombok)

## Implementation steps

1. Write `V8__map_locations.sql`.
2. Create `MapLocation` entity + repository + exceptions.
3. Register `MAP_LOCATION_NOT_FOUND` and `UNLOCK_LESSON_MISMATCH` in `GlobalExceptionHandler` + `ErrorCode` enum (check `com.dauviet.common.error.ErrorCode` for the pattern — it is an enum of code names).
4. Compile: `./mvnw -q -DskipTests compile` from `dau-viet-backend/`.

## Todo

- [ ] V8 migration file
- [ ] `MapLocation` entity
- [ ] `MapLocationRepository`
- [ ] `MapLocationNotFoundException`, `UnlockLessonMismatchException`
- [ ] `ErrorCode.MAP_LOCATION_NOT_FOUND`, `ErrorCode.UNLOCK_LESSON_MISMATCH` + handler entries

## Success criteria

- `mvnw compile` clean.
- `FlywayMigrationIT` passes (V8 applies cleanly on Postgres container).
- `AbstractPostgresIT.clearAuthoringTables` — add `delete from map_locations` in phase 05 if ITs seed locations (cleanup order: before `lessons`/`historical_events` deletes).

## Risks

- `lessons` table FK: `unlock_lesson_id REFERENCES lessons(id)` — nullable, so locations independent of lessons OK. Deleting/archiving a lesson does NOT cascade; service validates `eventId` match on write.
- `EventStatus` check done at API layer, not FK (events can be DRAFT while locations exist — admin configures locations on drafts before publish).

## Security considerations

- No learner data stored. Coordinates are admin-authored reference data — no PII.
