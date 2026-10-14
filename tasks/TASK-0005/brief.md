# TASK-0005: Spring Boot Backend Foundation + Historical Event API

## Goal

Bootstrap `dau-viet-backend` (Java 21 + Spring Boot + PostgreSQL + Flyway + Maven) as a modular monolith, and ship the first public read API for Historical Events so the Flutter app can later switch from mock data to real backend data.

## Requirements and acceptance criteria

- AC-1: `dau-viet-backend` contains a buildable Spring Boot application (Maven wrapper, `pom.xml`, main class) that compiles under Java 21.
- AC-2: `docker compose` provides PostgreSQL locally; Flyway migrations run successfully on a clean database; `ddl-auto` is not `update`.
- AC-3: Module `historicalevent` follows the modular monolith layout (api/application/domain/infrastructure) with entity, JPA repository, service, DTOs and mapper; no business logic in controllers; constructor injection only.
- AC-4: `GET /api/v1/events` returns a paginated list and `GET /api/v1/events/{id}` returns a detail, both learner-safe (only published/visible events); JPA entities are never serialized; errors follow the `{code, message, details, traceId}` envelope with correct HTTP status (400/404/500).
- AC-5: Database schema uses UUID PKs, snake_case, `timestamptz` UTC, sensible indexes/constraints, and does not block a future `historical_events 1-N lessons` relation.
- AC-6: An idempotent dev-only seed provides the Bạch Đằng 938 event; the seed never auto-loads in production profile.
- AC-7: Spring Security foundation is present (permit-all for public read endpoints, deny-by-default elsewhere), CORS configured for development without wildcard exposure in production, Actuator health endpoint enabled.
- AC-8: Unit/integration tests pass: context load, Flyway+PostgreSQL (Testcontainers preferred), repository, controller/service, validation/not-found, draft-not-exposed. Failures must be honestly reported as NOT VERIFIED if the environment cannot run them.
- AC-9: `README` (module or root section) documents how to run backend + database locally; Flutter contract deltas vs. `lib/mock` models are recorded for the next task.

## Scope

- `dau-viet-backend/` (new module)
- `docker-compose.yml` (root, if absent) or `dau-viet-backend/docker-compose.yml`
- `tasks/TASK-0005/`
- `docs/` updates where behavior/contract changed (README run instructions, API notes)
- `.harness/config.json` (backend module registration)

## Constraints and risk

- Risk lane: **high-risk** (new public API + Flyway migrations + module bootstrap).
- Dependencies: TASK-0003 (harness). Related: TASK-0004 (mobile) for contract comparison only — no Flutter edits.
- Invariants: no hard-coded event data; no entity serialization; no field injection; no event-specific branches; no secrets committed.
- Environment: Docker daemon must run for integration tests; JAVA_HOME must point to `E:\Java\jdk-21` on this machine.

## Plan

`plans/2026-10-15-backend-foundation/plan.md`

## Verification mapping

| AC | Check | Expected outcome | Evidence artifact |
|---|---|---|---|
| AC-1 | `mvn -q compile` (JAVA_HOME=E:\Java\jdk-21) | BUILD SUCCESS | plans/reports/… |
| AC-2 | `docker compose up -d`; `mvn flyway:info`/`mvn test` | migrations applied on clean DB | plans/reports/… |
| AC-3..AC-7 | code review + unit tests | structure matches spec; errors envelope correct | plans/reports/… |
| AC-8 | `mvn test` (+ Testcontainers) | green suite; draft hidden | plans/reports/… |
| AC-9 | docs review | run instructions + contract delta note exist | docs/… |

## Handoff

Record actual checks, remaining blockers and next action. Execution status lives only in `task.json`.
