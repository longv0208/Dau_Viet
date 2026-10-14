# Phase 03 — historicalevent domain + Flyway V1 + JPA repository

## Context links
- Plan: [plan.md](plan.md)
- DB rules: `docs/CODING_RULES.md` §4 (Flyway only, snake_case, UUID PKs, timestamptz)
- DB design: `docs/DATABASE_DESIGN.md` §3 (`historical_events` table)
- Module layout: `docs/TECH_STACK.md` §3

## Overview
- **Priority:** P1
- **Status:** completed
- **Effort:** 2h
- Define `historical_events` schema via Flyway V1, build JPA entity, repository interface, and a domain `EventStatus` enum.

## Key insights
- `docs/DATABASE_DESIGN.md` lists `id, title, period, start_year, summary, cover_asset_id, status`. The brief adds `location`, `tags`, `description`, and Flutter needs `era` — **design decision**: extend the doc'd schema rather than create a second table.
- `cover_asset_id` is replaced with `cover_asset_key TEXT` for now — deferring `assets` table keeps V1 minimal (YAGNI). Storing a logical storage key (e.g., `events/bach-dang-938/hero.jpg`) keeps a future `assets` migration trivial: a later migration can populate `assets` and convert the column to a FK.
- `tags` stored as `text[]` (Postgres array) — simple, supports `= ANY` query; revisit when tag taxonomy is needed.
- The `lessons.event_id` FK comes in a later migration when `lessons` is built — V1 stays single-table, but `historical_events` is already correctly keyed by UUID so the future FK is trivial.

## Requirements
- Migration `src/main/resources/db/migration/V1__create_historical_events.sql`:
  ```sql
  CREATE TABLE historical_events (
      id              UUID PRIMARY KEY,
      title           VARCHAR(255) NOT NULL,
      era             VARCHAR(100),
      period          VARCHAR(100),
      start_year      INTEGER,
      summary         TEXT NOT NULL,
      description     TEXT,
      location        VARCHAR(255),
      cover_asset_key VARCHAR(512),
      tags            TEXT[] NOT NULL DEFAULT '{}',
      status          VARCHAR(24) NOT NULL DEFAULT 'DRAFT',
      created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
      CONSTRAINT chk_historical_events_status CHECK (status IN ('DRAFT','PUBLISHED','ARCHIVED'))
  );
  CREATE INDEX idx_historical_events_status      ON historical_events(status);
  CREATE INDEX idx_historical_events_start_year  ON historical_events(start_year);
  CREATE INDEX idx_historical_events_pub_year    ON historical_events(start_year) WHERE status = 'PUBLISHED';
  ```
- JPA entity `HistoricalEvent` in `com.dauviet.historicalevent.domain` — fields mirror columns, `Instant` for timestamps, `List<String>` for tags mapped via Hibernate's `@JdbcTypeCode(SqlTypes.ARRAY)` or a `AttributeConverter<List<String>, String[]>` (prefer `SqlTypes.ARRAY` — simplest on Hibernate 6).
- Enum `EventStatus { DRAFT, PUBLISHED, ARCHIVED }` mapped via `@Enumerated(EnumType.STRING)` with `@JdbcTypeCode(SqlTypes.NAMED_ENUM)`? — **simpler**: keep `VARCHAR` + `EnumType.STRING`; the CHECK constraint enforces values at DB level. Avoids enum-type migrations later.
- `HistoricalEventRepository extends JpaRepository<HistoricalEvent, UUID>` with:
  - `Page<HistoricalEvent> findByStatus(EventStatus status, Pageable pageable)`
  - `Optional<HistoricalEvent> findByIdAndStatus(UUID id, EventStatus status)`
- Service-level rule: only `status = PUBLISHED` rows reach learners (enforced in application service, phase-04).
- Auditing: rely on `created_at`/`updated_at` DB defaults; add `@PreUpdate` or Hibernate `@UpdateTimestamp` for `updated_at`.

## Architecture

```
com.dauviet.historicalevent/
├── domain/
│   ├── HistoricalEvent.java           # @Entity @Table("historical_events")
│   └── EventStatus.java
├── application/
│   └── HistoricalEventService.java    # phase-04
├── infrastructure/
│   └── persistence/
│       └── HistoricalEventRepository.java
└── api/
    ├── HistoricalEventController.java # phase-04
    ├── dto/                           # phase-04
    └── mapper/                        # phase-04
```

## Related code files
- Create: `src/main/resources/db/migration/V1__create_historical_events.sql`
- Create: `src/main/java/com/dauviet/historicalevent/domain/HistoricalEvent.java`
- Create: `src/main/java/com/dauviet/historicalevent/domain/EventStatus.java`
- Create: `src/main/java/com/dauviet/historicalevent/infrastructure/persistence/HistoricalEventRepository.java`

## Implementation steps
1. Write `V1__create_historical_events.sql` exactly as above (no `IF NOT EXISTS`, no `ON CONFLICT`, no comments about specific events — schema stays generic).
2. Write `EventStatus` enum.
3. Write `HistoricalEvent` entity:
   - `@Id @Column(name="id") private UUID id;` — application assigns UUID (via `UUID.randomUUID()` in service on create); avoids needing a `@GeneratedValue` for now and keeps seeding deterministic.
   - `@Enumerated(EnumType.STRING) @Column(name="status") private EventStatus status;`
   - `@JdbcTypeCode(SqlTypes.ARRAY) @Column(name="tags", columnDefinition="text[]") private List<String> tags = new ArrayList<>();`
   - `@CreationTimestamp`/`@UpdateTimestamp` on `created_at`/`updated_at`.
   - No-arg protected constructor + builder-ish setters or a package-private constructor for tests.
4. Write `HistoricalEventRepository` interface.
5. Boot the app under `local` profile; Flyway runs V1 on the empty `dauviet` DB; `ddl-auto=validate` confirms entity maps cleanly.

## Todo checklist
- [ ] `V1__create_historical_events.sql` runs cleanly on empty Postgres
- [ ] CHECK constraint on `status` rejects invalid value (verified via repository test in phase-05)
- [ ] `historical_events` table uses `timestamptz`, `uuid`, `text[]` as specified
- [ ] Entity maps `List<String> tags` via `SqlTypes.ARRAY`
- [ ] Repository exposes `findByStatus(Pageable)` and `findByIdAndStatus`
- [ ] No `assets` table or FK (documented design decision)

## Success criteria
- `flyway_schema_history` contains V1 applied.
- Inserting `status='PUBLISHED'` + `status='DRAFT'` and querying `findByStatus(PUBLISHED)` returns only the published row (test in phase-05).
- `psql \d historical_events` shows all columns, indexes, check constraint.

## Risk assessment
- `text[]` array mapping: confirm Hibernate 6.6+ `SqlTypes.ARRAY` works on `List<String>`; fallback to `AttributeConverter` if driver complains.
- `EnumType.STRING` vs `NAMED_ENUM`: sticking with VARCHAR keeps schema simple and avoids creating a Postgres enum that would need separate migrations when values grow.

## Security considerations
- No PII in this table — safe.
- Do not log entity contents at INFO level beyond ID + status.

## Next steps
- Phase 04 — application service, controller, DTO, pagination, dev seed.
