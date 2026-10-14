# Phase 05 — Tests, build verification, Flutter contract note

## Context links
- Plan: [plan.md](plan.md)
- Testing rules: `docs/CODING_RULES.md` §8
- Workflow: `docs/AGENT_WORKFLOW.md` (tester agent runs tests; recorder reports real outcomes)

## Overview
- **Priority:** P1
- **Status:** completed
- **Effort:** 2.5h
- Cover the foundation with unit + integration tests; document the Flutter contract delta.

## Key insights
- Testcontainers requires a running Docker daemon — pre-check (`docker info`); if unavailable, run only `@WebMvcTest` slices + plain JUnit and mark integration as NOT VERIFIED in the test report.
- `@WebMvcTest` loads only the MVC slice — fast, no DB needed; mock the service.
- `@DataJpaTest` + `@Testcontainers` boots a real Postgres — best place to prove Flyway migrations + entity mapping + array/list mapping.

## Requirements
- **Unit (no Spring):**
  - `HistoricalEventMapperTest` — entity → summary/detail DTO; empty tags → empty list; null fields → null.
  - `GlobalExceptionHandlerTest` — given exception types, produces correct `ApiError` shape with `traceId` (mock MDC).
- **MVC slice (`@WebMvcTest(HistoricalEventController.class)`):**
  - GET `/api/v1/events` → 200, JSON shape matches `PageResponse`
  - GET `/api/v1/events?page=-1` → 400 `VALIDATION_ERROR`
  - GET `/api/v1/events?size=101` → 400 `VALIDATION_ERROR`
  - GET `/api/v1/events?sort=evil;` → 400 `VALIDATION_ERROR`
  - GET `/api/v1/events/{valid-uuid}` → 200 with detail
  - GET `/api/v1/events/{missing-uuid}` → 404 `EVENT_NOT_FOUND`
  - GET `/api/v1/events/not-a-uuid` → 400 `MALFORMED_ID`
  - GET `/actuator/health` → 200 (allowed unauthenticated)
  - GET `/api/v1/admin/anything` → 401 (security foundation)
  - Response includes `X-Request-Id` header
- **JPA + Testcontainers (`@DataJpaTest` + `@Testcontainers` + `@AutoConfigureTestDatabase(replace=NONE)`):**
  - `HistoricalEventRepositoryIT` — save PUBLISHED + DRAFT, `findByStatus(PUBLISHED)` returns only PUBLISHED; `findByIdAndStatus(DRAFT)` empty for PUBLISHED id; tags array round-trips; `status` CHECK rejects invalid enum value (test via raw JDBC `jdbcTemplate.execute("INSERT ... status='BOGUS'")` → `DataIntegrityViolationException`).
  - `FlywayMigrationIT` — context starts; assert `flyway_schema_history` has version `1`.
- **Context test:**
  - `DauVietApplicationTests` (`@SpringBootTest` + Testcontainers datasource) — context loads, `HistoricalEventRepository` bean present.
- **Seed test:**
  - `EventSeedServiceTest` — `@DataJpaTest` + Testcontainers; run `upsertBachDang()` twice; assert exactly one row with slug `bach-dang-938`.

## Related code files
- Create: `src/test/java/com/dauviet/DauVietApplicationTests.java`
- Create: `src/test/java/com/dauviet/historicalevent/api/HistoricalEventControllerTest.java`
- Create: `src/test/java/com/dauviet/historicalevent/api/mapper/HistoricalEventMapperTest.java`
- Create: `src/test/java/com/dauviet/historicalevent/application/EventSeedServiceIT.java`
- Create: `src/test/java/com/dauviet/historicalevent/infrastructure/persistence/HistoricalEventRepositoryIT.java`
- Create: `src/test/java/com/dauviet/common/error/GlobalExceptionHandlerTest.java`
- Create: `src/test/java/com/dauviet/common/FlywayMigrationIT.java`
- Create: `src/test/resources/application-test.yml` (already in phase-01)
- Create: `docs/backend-flutter-contract-notes.md` — Flutter contract delta (see below)

## Implementation steps
1. Pre-check: `docker info` — record outcome in test report; abort integration tests cleanly if daemon down.
2. Write `AbstractPostgresIT` base class wiring `@Testcontainers` `@Container PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")` + `@DynamicPropertySource` to override `spring.datasource.*`.
3. Write the test classes above; use `@MockBean`/`@MockitoBean` (Boot 3.4) for service in `@WebMvcTest`.
4. Run `$env:JAVA_HOME='E:\Java\jdk-21'; ./mvnw verify` — all green.
5. Write `docs/backend-flutter-contract-notes.md` with the field-by-field delta table below; do NOT touch Flutter code.
6. Capture API response sample to `docs/backend-flutter-contract-notes.md` (literal `curl` output).

## Flutter contract delta (to record in `docs/backend-flutter-contract-notes.md`)

| Backend field | Flutter `TimelineMilestoneModel` / `HistoricalEventModel` field | Action for next task |
|---|---|---|
| `id` (UUID) | `id` (string `'evt_bach_dang_938'`) / `eventId` | Map UUID → string; consider keeping `slug` for legacy ids; replace `evt_*` constants with UUIDs |
| `slug` | — | New; useful for human-readable URLs, logs |
| `title` | `title` | Direct map |
| `era` | `era` | Direct map |
| `period` | `yearLabel` | Direct map (rename semantic) |
| `startYear` | `yearValue` / `year` | Direct map (int) |
| `summary` | `summary` (detail) / `description` (timeline) | Direct map; timeline `description` maps to backend `summary` |
| `description` | (detail body) | Long-form, currently unused by Timeline; consumed by `HistoricalEventModel.summary` later |
| `location` | — | New; reserved for detail screen |
| `coverAssetKey` | `heroBannerUrl` | Client resolves key → asset URL (future asset service or static map in adapter) |
| `tags` | `badgeText`? | No direct match; either derive badge from tags or keep badge as a separate UI-only field |
| `status` | `isActive` | Backend returns only PUBLISHED; `isActive` becomes `true` when `id` exists in list |
| — | `subtitle` | No backend equivalent — Flutter derives from `title`/`period`, or extend DTO later |
| — | `lessonIds` | Out of scope — served by future `lessons` endpoint |

## Todo checklist
- [ ] `mvnw verify` green locally (or marked NOT VERIFIED if Docker absent)
- [ ] `@WebMvcTest` covers all eight controller cases above
- [ ] `@DataJpaTest` + Testcontainers confirms Flyway V1 + array mapping
- [ ] `EventSeedServiceIT` proves idempotent upsert
- [ ] `docs/backend-flutter-contract-notes.md` written with delta table
- [ ] No mock data in controller/service (only seed)

## Success criteria
- All tests pass with `mvnw verify` under `JAVA_HOME=E:\Java\jdk-21`
- Coverage report shows event/api/common packages exercised
- Flutter contract note lists every field decision for next task

## Risk assessment
- **Docker daemon down** → run `mvnw -Dtest='!*IT' verify` for unit/MVC only; record integration as NOT VERIFIED.
- Testcontainers image pull may be slow on first run; acceptable one-time cost.

## Security considerations
- Tests assert 401 on a non-public endpoint and that DRAFT events are not leaked (404 not 403).

## Next steps
- Phase 06 — harness task registration + docs.
