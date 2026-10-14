# TASK-0005 handoff

`dau-viet-backend` bootstrapped and verified end-to-end: Maven build green, Flyway V1 on clean Postgres 16, `GET /api/v1/events` + `/{id}` serve published-only DTOs with the unified error envelope, dev seed idempotent under `local` profile, backend module registered `active` in `.harness/config.json` with two real gates.

## Intent

Bootstrap the backend as a Java 21 / Spring Boot 3.4.13 modular monolith on PostgreSQL + Flyway, and ship the first public learner-safe read API for Historical Events so Flutter can later drop mock data.

## What was done

- Scaffolded `dau-viet-backend/` — Maven Wrapper, `pom.xml` (Spring Boot 3.4.13, Java 21, web/data-jpa/validation/security/actuator/flyway/postgresql + Testcontainers), `maven-failsafe-plugin` so `verify` runs `*IT`.
- `docker-compose.yml` — `postgres:16-alpine` on host port 5433, db/user `dauviet`/`dauviet`, healthcheck, named volume.
- `common/` infra — `ApiError{code,message,details,traceId}`, `GlobalExceptionHandler` (400/404/405/500 + `MALFORMED_ID` on bad UUID path var), `TraceIdFilter` (MDC + `X-Request-Id` echo), `SecurityConfig` (stateless, permit `GET /api/v1/events/**` + actuator health/info, deny-by-default rest → 401 JSON), `CorsConfig` + `CorsProperties` (explicit origins; empty list in default profile), Actuator exposing only `health,info`.
- `historicalevent/` module — `HistoricalEvent` entity (UUID PK, `slug` unique, `tags` as `text[]` via `@JdbcTypeCode(SqlTypes.ARRAY)`, `status` enum string, `@CreationTimestamp`/`@UpdateTimestamp`), `HistoricalEventRepository`, `HistoricalEventService` (published-only, read-only tx), summary/detail DTO records, plain-Java mapper, controller with page/size/sort validation (sort whitelist `{startYear,title}`).
- Flyway `V1__create_historical_events.sql` — snake_case, `timestamptz`, CHECK on `status`, unique slug, indexes on `status`/`start_year` + partial published index.
- Dev seed — `EventSeedService` upsert keyed on slug `bach-dang-938` (fixed UUID `00000000-0000-0000-0000-000000000001`), gated by `@Profile("local")` + `app.seed.enabled=true` in `EventSeedRunner`; disabled in default/test profiles.
- Tests — `AbstractPostgresIT` shared static `postgres:16-alpine` container; `FlywayMigrationIT` (schema history + 14 columns + CHECK rejection), `HistoricalEventRepositoryIT` (published-only paging, draft hidden, tags round-trip), `EventSeedServiceIT` (insert-only: no duplicate + no overwrite of local edits), `HistoricalEventControllerTest` (envelope, pagination validation, 404/400/401, `X-Request-Id`), `HistoricalEventMapperTest`, `ActuatorHealthIT` (real HTTP 200 UP). 22/22 green.
- Docs — `docs/backend-runbook.md` (prereqs incl. broken-JAVA_HOME workaround, compose/run/verify commands, troubleshooting), `docs/backend-flutter-contract-notes.md` (field-by-field delta vs `lib/mock` models + decisions for the mobile task), `docs/API_SPEC.md` events section marked implemented with real payload, `README.md` hiện trạng updated, `AGENTS.md` registry line updated.
- Harness — `.harness/config.json` backend → `active`, manifests `[pom.xml, mvnw.cmd, docker-compose.yml]`, gates `backend-compile` + `backend-test` (`cmd.exe /c "set JAVA_HOME=...&& mvnw.cmd ..."`).

## Files changed or created

- `dau-viet-backend/**` — entire new module (pom, wrapper, compose, sources, tests, resources).
- `.harness/config.json` — backend status/gates.
- `docs/backend-runbook.md`, `docs/backend-flutter-contract-notes.md` — new.
- `docs/API_SPEC.md`, `README.md`, `AGENTS.md` — updated for implemented endpoints / module status.
- `tasks/TASK-0005/{brief.md,task.json,handoff.md}` — task record.
- `plans/2026-10-15-backend-foundation/` — plan + 6 phase files, statuses completed.

## Assumptions and invariants

- `JAVA_HOME` system env is broken on this machine; every Maven invocation must set `JAVA_HOME=E:\Java\jdk-21` first (already encoded in harness gates).
- Backend is authoritative; only `PUBLISHED` events are learner-visible; entities are never serialized.
- `ddl-auto: validate` everywhere — schema changes only via new Flyway migrations.
- Seed never runs outside `local` profile + `app.seed.enabled=true`; production must keep `app.seed.enabled` unset/false.
- `cover_asset_key` is a plain column — no `assets` table yet (deliberate YAGNI deferral).
- No JWT yet: security is foundation-only (permit public GETs, 401 rest). Auth is a later task.

## Acceptance criteria status

| AC | Status | Evidence ref |
|---|---|---|
| AC-1 | done | `dau-viet-backend/pom.xml`, `mvnw.cmd`; `mvn -DskipTests compile` BUILD SUCCESS |
| AC-2 | done | `dau-viet-backend/docker-compose.yml`, `V1__create_historical_events.sql`, `FlywayMigrationIT` green; `ddl-auto: validate` |
| AC-3 | done | `historicalevent/{api,application,domain,infrastructure}` tree; constructor injection throughout |
| AC-4 | done | `HistoricalEventControllerTest` (8 tests); live smoke: paginated list + detail + `EVENT_NOT_FOUND`/`MALFORMED_ID` envelopes |
| AC-5 | done | `V1__create_historical_events.sql`; `FlywayMigrationIT` asserts columns + CHECK; lessons FK ready (no schema blocker) |
| AC-6 | done | `EventSeedServiceIT` insert-only verified (2 tests); `@Profile("local")` + `app.seed.enabled` gate |
| AC-7 | done | `SecurityConfig`; smoke test 401 on unknown path, `X-Request-Id` echoed; CORS origins empty by default |
| AC-8 | done | `mvnw verify` — **22/22 tests** green (13 surefire + 9 Testcontainers IT incl. real `/actuator/health` 200/UP) |
| AC-9 | done | `docs/backend-runbook.md`, `docs/backend-flutter-contract-notes.md`, README section |

## Checks actually run

- `mvnw.cmd -q -DskipTests compile` (JAVA_HOME=`E:\Java\jdk-21`) — BUILD SUCCESS.
- `mvnw.cmd verify` — BUILD SUCCESS, **22/22 tests** (13 surefire + 9 failsafe on `postgres:16-alpine`); re-run after post-review fixes green.
- Post-review fixes applied + verified: `NoResourceFoundException`→`NOT_FOUND`; 403→`FORBIDDEN`; `EventSeedService` insert-only; `DauVietApplicationTests` real `@SpringBootTest` context-load; `parseSort` strict; dead `application-test.yml` deleted.
- Follow-up fixes (user review): `TraceIdFilter` sanitizes `X-Request-Id` (`^[A-Za-z0-9-]{1,64}$`, else fresh UUID); `EventSeedService` truly insert-only; `HistoricalEventControllerTest` renamed to `unknownEndpoint_requiresAuthentication` + `actuatorHealth_isPublic`; new `ActuatorHealthIT` — real HTTP `GET /actuator/health` → 200 `"status":"UP"` on random port; `EventSeedServiceIT` now asserts second run is no-op AND doesn't overwrite local edits; `.github/workflows/backend-ci.yml` added (Java 21, Maven cache, `./mvnw verify` on ubuntu-latest with Docker).
- `docker compose up -d` + `spring-boot:run -Dspring-boot.run.profiles=local` — app healthy; Flyway applied V1; seed row present (count=1); `GET /api/v1/events` returns `bach-dang-938`; detail endpoint, `EVENT_NOT_FOUND`, `MALFORMED_ID`, 401 envelope, `X-Request-Id` all verified via curl; `psql \d` confirmed indexes + CHECK.
- Tester report: `plans/reports/tester-261015-0113-task0005-verify.md` — PASS, 19/19 tests at report time; final suite after follow-up fixes is **22/22** (added `ActuatorHealthIT` + second `EventSeedServiceIT` test + `actuatorHealth_isPublic`).
- Independent review: `plans/reports/code-reviewer-261015-0113-task0005-review.md` — PASS WITH P2 (0 P1).
- Post-review fixes applied + re-verified: `GlobalExceptionHandler` `NoResourceFoundException` → `NOT_FOUND` (was `EVENT_NOT_FOUND`); `AccessDeniedHandler` 403 → `FORBIDDEN` code; `EventSeedService` `setId` only on insert branch; `DauVietApplicationTests` now a real `@SpringBootTest` context-load on the shared Testcontainers container; `parseSort` rejects malformed direction/extra segments; dead `application-test.yml` deleted. `mvnw verify` re-run green: 22/22 (surefire 13 + failsafe 9).

## Unresolved blockers

- None for code. `pwsh` 7 is not installed, so `harness.ps1 verify/finish` (which needs the `harness-self-test` gate) cannot run locally — recorded as a known environment limitation, same as TASK-0003.

## Limitations

- `publishedAt` in the detail DTO is currently `null` — no `published_at` column yet (fold into the publish-workflow task).
- `tags` stored as `text[]`; revisit if faceted search/tag admin is scoped.
- `sort` whitelist is `{startYear,title}` only.
- No `lessons` table yet — the 1-N relation lands in a later migration.

## Next action

Run `pwsh -File scripts/harness/harness.ps1 verify -TaskId TASK-0005` on a pwsh-7 host to record passing gate evidence, then `finish`. Next task: Flutter events integration per `docs/backend-flutter-contract-notes.md` (or lessons schema + admin authoring API).
