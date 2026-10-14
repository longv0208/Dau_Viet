# Code Review — TASK-0005 Spring Boot Backend Foundation + Historical Event API

Reviewer: code-reviewer (independent; did not write the code under review)
Date: 2026-10-15 01:13 +07:00
Scope: `dau-viet-backend/**`, `.harness/config.json`, `docs/backend-runbook.md`, `docs/backend-flutter-contract-notes.md`, `docs/API_SPEC.md`, `README.md`, `AGENTS.md`, `tasks/TASK-0005/*`, `plans/2026-10-15-backend-foundation/*`
Evidence cross-checked: `plans/reports/tester-261015-0113-task0005-verify.md`, `dau-viet-backend/target/{surefire,failsafe}-reports/*`, `tasks/TASK-0005/handoff.md`

## Verdict

PASS WITH P2 — all 9 acceptance criteria are met by the implementation as verified by code inspection and the tester report (19/19 tests green, BUILD SUCCESS under `mvnw verify`). No P1 (AC-blocking / invariant / security) findings. Four P2 findings and three P3 nits below; none block handoff.

## Per-AC status

| AC | Status | Evidence |
|---|---|---|
| AC-1 buildable Java 21 app | PASS | `pom.xml` parent `spring-boot-starter-parent:3.4.13`, `maven.compiler.release=21`, wrapper present (`mvnw`, `mvnw.cmd`, `.mvn/wrapper/maven-wrapper.properties` — `only-script` distro, jar intentionally gitignored). Dependencies are all needed: web, data-jpa, validation, security, actuator, flyway-core + flyway-database-postgresql, postgresql runtime; test stack = starter-test + testcontainers + security-test. Nothing unnecessary. `target/` artifacts exist proving a real build ran. |
| AC-2 compose + Flyway + no `ddl-auto=update` | PASS | `docker-compose.yml` postgres:16-alpine on 5433→5432 with healthcheck + named volume. `application.yml` has `ddl-auto: validate`, `open-in-view: false`, `flyway.enabled: true`. `FlywayMigrationIT` (3 tests) green on clean Testcontainers Postgres. |
| AC-3 modular monolith layout | PASS | `historicalevent/{api,application,domain,infrastructure}` exactly as planned. Controller only validates + delegates. Grep of `src/main/java` for `@Autowired`: zero hits — constructor injection throughout production code. |
| AC-4 paginated GET + detail + DTOs only + error envelope | PASS | Controller returns `PageResponse<HistoricalEventSummaryDto>` and `HistoricalEventDetailDto` — never the entity. Errors go through `GlobalExceptionHandler` and security entry points, all emitting `{code,message,details,traceId}`. Tests cover envelope, 400/404/401, `X-Request-Id` header. |
| AC-5 UUID PK, snake_case, timestamptz, indexes, CHECK, lessons-FK ready | PASS | V1 SQL: `id UUID PRIMARY KEY`, all snake_case, `timestamptz default now()`, `chk_historical_events_status` CHECK, indexes on `status`/`start_year` + unique slug + partial published index. `lessons.event_id UUID REFERENCES historical_events(id)` in DATABASE_DESIGN works against this PK. |
| AC-6 idempotent dev-only seed | PASS | `EventSeedRunner` gated by `@Profile("local")` AND `@ConditionalOnProperty(app.seed.enabled=true)`; `application.yml` defaults `app.seed.enabled=false`; seed upserts keyed on `slug` (unique index enforces it at DB level). `EventSeedServiceIT` proves double-run → 1 row. Seed does not run in tests (no `local` profile, `enabled=false`). |
| AC-7 security foundation | PASS | `SecurityConfig`: stateless, CSRF/basic/form-login/logout disabled, permits `GET /api/v1/events` + `/api/v1/events/*` + actuator health/info, `anyRequest().authenticated()` → 401 JSON via entry point. CORS origins property-driven; `application.yml` ships `allowed-origins: []` (no wildcard); local profile lists explicit dev origins. Actuator exposure `health,info` only. |
| AC-8 tests pass | PASS | `mvnw verify` green per tester report + surefire/failsafe XMLs in `target/`: 12 unit/WebMvc + 7 Testcontainers IT = 19/19. Covers clean-DB Flyway, published-only repo, seed idempotency, controller validation/404/malformed-id/401, draft hidden. |
| AC-9 docs | PASS | `docs/backend-runbook.md` (run instructions, JAVA_HOME workaround, troubleshooting), `docs/backend-flutter-contract-notes.md` (field-by-field delta vs `lib/mock`), `README.md` and `docs/API_SPEC.md` updated, `AGENTS.md` registry line updated, `.harness/config.json` backend `active` with two real gates. |

## Invariant checks

- No field injection in `src/main/java` (0 hits). Constructor injection everywhere.
- No entity serialized: both endpoints return DTOs; mapper is a plain `@Component`.
- No business logic in controller: pagination/validation only; "published-only" rule lives in `HistoricalEventService` + repository.
- No event-specific branches in generic handlers/controllers; Bạch Đằng specifics are isolated in `EventSeedService`.
- No secrets: `application-local.yml` holds dev-only defaults behind `${DB_*:...}` env overrides; `.env` gitignored at root.
- `TraceIdFilter` clears MDC in `finally` (line 40-42). Correct.
- Errors not swallowed: catch-all handler logs full stack with traceId server-side, returns generic body.
- File sizes all under 200 lines; Java PascalCase, non-Java kebab-case. Compliant.

## Findings

### P2-1 — `NoResourceFoundException` mapped to `EVENT_NOT_FOUND` is semantically wrong
`GlobalExceptionHandler.java:82-85` returns `EVENT_NOT_FOUND` for any unmapped static-resource miss. A miss on e.g. `/favicon.ico` or a future non-event path would claim "event not found". Either map it to a generic `NOT_FOUND` code or drop the handler (deny-by-default security already 401s unauthenticated unknown paths; authenticated misses would currently get the misleading code). Low impact today because only `/api/v1/events/**` is public, but the code name leaks into a generic handler.

### P2-2 — `AccessDeniedHandler` reuses `UNAUTHORIZED` for HTTP 403
`SecurityConfig.java:67-70` writes 403 status with code `UNAUTHORIZED`. API_SPEC §1 defines 403 as a distinct semantic ("không được phép thao tác"). Add a `FORBIDDEN` error code so clients can distinguish "not logged in" (401) from "logged in but not allowed" (403) once JWT lands.

### P2-3 — `EventSeedService.upsertBachDang` mutates the PK of a managed entity
`EventSeedService.java:37-39`: `findBySlug(...).orElseGet(HistoricalEvent::new)` then `e.setId(BACH_DANG_ID)` unconditionally. On the normal re-run path the loaded row already has `BACH_DANG_ID`, so `setId` is a no-op — tests pass. But if a row with slug `bach-dang-938` ever exists under a *different* id (e.g. manually inserted), this writes a new PK onto a Hibernate-managed entity — undefined behavior (Hibernate may silently skip, throw, or corrupt the persistence context). Fix: only `setId` inside the `orElseGet`/insert branch, or `if (e.getId() == null) e.setId(...)`. Edge-case, but the fix is one line.

### P2-4 — Plan-vs-implementation gap: `DauVietApplicationTests` is a placeholder, not a context-load test
Phase-05 required "`@SpringBootTest` + Testcontainers datasource — context loads". `DauVietApplicationTests.java` has no `@SpringBootTest` and asserts nothing (`applicationClassIsLoadable` is a no-op). The ITs do boot the JPA slice so real coverage exists, and `WebMvcTest` boots the MVC slice — full-context load is the only gap. Either restore a real `@SpringBootTest` context test or update the plan/handoff wording so evidence claims match reality. Not an AC-8 blocker (all listed behaviors are covered) but it is a doc-vs-code honesty issue under AGENTS.md completion rules.

### P3-1 — `SecurityConfig` uses a private `new ObjectMapper()` instead of the Spring bean
`SecurityConfig.java:36`. Works today because `ApiError` has no JSR-310 fields, but it bypasses the app's Jackson customizations (`write-dates-as-timestamps: false` etc.). Inject the configured `ObjectMapper` for consistency when error payloads grow.

### P3-2 — `application-test.yml` is dead config
No test activates the `test` profile (no `@ActiveProfiles`, no `spring.profiles.active` in test config). The file's `seed.enabled=false` + CORS origins are never read; datasource comes from `AbstractPostgresIT` `@DynamicPropertySource` anyway. Either delete it or activate it — current state is misleading.

### P3-3 — Sort param silently accepts garbage after first comma
`HistoricalEventController.parseSort` (lines 63-71): `?sort=startYear` works, `?sort=startYear,asc` works, but `?sort=startYear,foo` quietly maps to ASC and `?sort=startYear,asc,extra` ignores the tail. Harmless, but trimming to a strict two-segment contract (`field,(asc|desc)`) with a `VALIDATION_ERROR` otherwise would match the whitelist's defensive intent.

## Doc/contract consistency

- `docs/API_SPEC.md` §2 correctly marks the events endpoints implemented with the real payload shape and notes `publishedAt` nullable until a `published_at` column exists — matches `HistoricalEventMapper.toDetailDto` returning `null` and the handoff limitation note.
- `backend-flutter-contract-notes.md` JSON sample matches actual DTO field order/shape.
- Handoff AC table claims match the code. The `evidenceRefs`/`reviewRefs` placeholders in `task.json` (`tester-261015-0000-...`) use a `0000` timestamp pattern while the real tester report is `tester-261015-0113-task0005-verify.md` — update the refs to the real filenames before `finish`.

## Recommendations

1. P2-4 first: either make `DauVietApplicationTests` a real `@SpringBootTest` context-load (it will reuse the static Testcontainers container so it is cheap) or amend the phase-05 requirement text.
2. P2-3: guard `setId` to the insert branch.
3. P2-1/P2-2: add `NOT_FOUND`/`FORBIDDEN` codes when the next endpoint lands; don't churn for the current scope.
4. Update `task.json` evidence refs to real report filenames.
5. Optional: delete or activate `application-test.yml`.

## Unresolved questions

- `publishedAt` is permanently `null` in detail DTO until a `published_at` column exists — confirmed deliberate, but there is no ticket tracking the follow-up; suggest folding into the future publish-workflow task.
