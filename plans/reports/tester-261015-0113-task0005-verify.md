# Tester Report — TASK-0005 Backend Verify

## Goal
Run `mvnw verify` on `dau-viet-backend/` for TASK-0005 (Spring Boot bootstrap + Historical Events read API). Confirm unit + Testcontainers ITs pass; produce per-class results.

## Environment
- OS: Windows 11 (win32), shell: bash via Git Bash
- Java: `JAVA_HOME='E:\Java\jdk-21'` (system JAVA_HOME broken — workaround applied per env notes)
- Docker: Docker Desktop 29.8.2 running; `dauviet-postgres` healthy on 5433; Testcontainers connected via npipe socket, spawned own `postgres:16-alpine` containers
- Working dir: `E:/Telegram Desktop/Dau viet/Dau_Viet/dau-viet-backend`

## Commands Run

| # | Command | Exit Code | Notes |
|---|---|---|---|
| 1 | `cmd.exe /c "set JAVA_HOME=E:\Java\jdk-21&& mvnw.cmd verify > ..\target-test-run.log 2>&1"` | 0 | Redirect inside `cmd.exe /c` did not produce a log file; output lost. No reliable evidence — rerun needed. |
| 2 | `JAVA_HOME='E:\Java\jdk-21' ./mvnw.cmd verify` (bash, output captured by harness) | **0** | Fresh run, all output captured. BUILD SUCCESS, total 17.184s. |

## Per-Class Test Results (fresh run, 2026-10-15 01:12 +07:00)

### Unit / WebMvc tests (maven-surefire-plugin)

| Test class | Tests | Failures | Errors | Skipped | Time |
|---|---|---|---|---|---|
| `com.dauviet.DauVietApplicationTests` | 1 | 0 | 0 | 0 | 0.058s |
| `com.dauviet.historicalevent.api.HistoricalEventControllerTest` | 8 | 0 | 0 | 0 | 3.625s |
| `com.dauviet.historicalevent.api.mapper.HistoricalEventMapperTest` | 3 | 0 | 0 | 0 | 0.102s |
| **Surefire total** | **12** | **0** | **0** | **0** | — |

### Integration tests (maven-failsafe-plugin, Testcontainers PostgreSQL 16.15)

| Test class | Tests | Failures | Errors | Skipped | Time |
|---|---|---|---|---|---|
| `com.dauviet.FlywayMigrationIT` | 3 | 0 | 0 | 0 | 7.623s |
| `com.dauviet.historicalevent.application.EventSeedServiceIT` | 1 | 0 | 0 | 0 | 1.008s |
| `com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepositoryIT` | 3 | 0 | 0 | 0 | 0.091s |
| **Failsafe total** | **7** | **0** | **0** | **0** | — |

`failsafe-summary.xml`: completed=7, errors=0, failures=0, skipped=0, flakes=0.

### Grand total

**19 tests run, 0 failures, 0 errors, 0 skipped — BUILD SUCCESS.**

Expected 19 (8 + 3 + 1 unit; 3 + 1 + 3 IT). Actual 19. Match.

## Failures
None.

## Notable Log Lines
- `BUILD SUCCESS` / `Total time: 17.184 s` / `Finished at: 2026-10-15T01:12:51+07:00`
- Testcontainers: `Connected to docker: Server Version: 29.8.2, API Version: 1.56` via `npipe:////./pipe/docker_engine`
- Flyway: `Successfully validated 1 migration`, `Schema "public" is up to date`
- Seed: `seeded historical event slug=bach-dang-938 id=00000000-0000-0000-0000-000000000001` (idempotent — ran twice in EventSeedServiceIT, second run did not insert duplicate)
- Spring Boot 3.4.13, Java 21.0.8
- Warning (non-blocking): `Using generated security password` — expected for dev/test default security config (AC-7 covers deny-by-default)
- Warning (non-blocking): `Mockito is currently self-attaching to enable the inline-mock-maker` — future JDK compat note only

## Verdict
**PASS** — 19/19 tests green; build verified end-to-end including Docker-backed Testcontainers ITs.

## Notes / Caveats
- JAVA_HOME workaround confirmed required: without prefix, Maven would pick broken system env. Used `JAVA_HOME='E:\Java\jdk-21'` inline env var in bash — worked.
- Docker availability: daemon healthy, Testcontainers 1.20.6 pulled/ran `postgres:16-alpine` successfully (DB version 16.15 reported by Hibernate).
- First `cmd.exe /c` invocation exit code was 0 but produced no log file — redirect was swallowed by quoting. Evidence above is from the second bash run, which is authoritative.
- No source code modified by tester.

## Acceptance criteria evidence (AC-8)
- context load: `DauVietApplicationTests` PASS
- Flyway+PostgreSQL: `FlywayMigrationIT` (3) PASS
- repository: `HistoricalEventRepositoryIT` (3) PASS
- controller/service: `HistoricalEventControllerTest` (8) PASS
- validation/not-found, draft-not-exposed: covered inside `HistoricalEventControllerTest` + `HistoricalEventRepositoryIT` suites (all green)
- seed idempotency: `EventSeedServiceIT` PASS — log shows second `seeded historical event slug=bach-dang-938` did not emit a second `insert into historical_events`

## Unresolved Questions
- None blocking. Mockito self-attach warning is cosmetic; consider adding `-javaagent` mockito config or upgrading when moving past JDK 21.
