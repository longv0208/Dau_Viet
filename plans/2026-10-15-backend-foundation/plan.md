---
title: "Spring Boot Backend Foundation + Historical Event API"
description: "Bootstrap dau-viet-backend as a modular monolith exposing public read APIs for published historical events backed by PostgreSQL/Flyway."
status: completed
priority: P1
effort: 12h
branch: main
tags: [backend, spring-boot, postgresql, flyway, foundation, api]
created: 2026-10-15
---

# Spring Boot Backend Foundation + Historical Event API

## Goal
Create `dau-viet-backend/` — a Java 21 / Spring Boot 3.4.x modular monolith exposing `GET /api/v1/events` (paginated) and `GET /api/v1/events/{id}` returning published historical events from PostgreSQL, with a unified error contract, Flyway-managed schema, dev seed data, and Testcontainers-backed tests. No Flutter refactor in this task.

## Phases

| # | Title | Status | File |
|---|-------|--------|------|
| 01 | Maven project skeleton + Docker Compose Postgres | completed | [phase-01](phase-01-maven-skeleton-docker-compose.md) |
| 02 | `common/` infra: error contract, security foundation, CORS, actuator | completed | [phase-02](phase-02-common-infra-error-security.md) |
| 03 | `historicalevent` domain + Flyway V1 + JPA repository | completed | [phase-03](phase-03-historical-event-domain-flyway.md) |
| 04 | REST API: controller, DTO/mapper, pagination, dev seed | completed | [phase-04](phase-04-rest-api-dto-seed.md) |
| 05 | Tests, build verification, Flutter contract note | completed | [phase-05](phase-05-tests-build-flutter-note.md) |
| 06 | Harness task.json + docs (README, registry) | completed | [phase-06](phase-06-harness-docs-registration.md) |

## Key decisions
- **Spring Boot**: `3.4.13` (latest 3.4.x patch at scaffold time; Boot 4.x exists but 3.4 line chosen for stability).
- **Group/artifact**: `com.dauviet` / `dau-viet-backend`; root package `com.dauviet`.
- **Port**: `8080` (server.port). DB `dauviet`/`dauviet`/`dauviet_dev` via env `SPRING_DATASOURCE_*` in `application-local.yml`; Compose service `postgres:16-alpine` on `5433->5432` to dodge local Postgres collisions.
- **Schema**: only `historical_events` in V1. `cover_asset_key TEXT` (defer `assets` table / FK — YAGNI, marked DESIGN DECISION in phase-03). Columns: `id uuid PK`, `title`, `period`, `era`, `start_year`, `summary`, `description`, `location`, `cover_asset_key`, `tags text[]`, `status varchar(24) default 'DRAFT'`, `created_at/updated_at timestamptz default now()`. Indexes: `(status)`, `(start_year)`. Lesson 1->N readiness: `event_id` will FK from future `lessons.event_id` — no schema change needed now.
- **No JWT**: Spring Security `SecurityFilterChain` permits `GET /api/v1/events/**` + actuator/health; denies rest with 401 (foundation only, JWT in a later task).
- **Error contract**: `{code, message, details, traceId}` — codes catalog in phase-02 (`EVENT_NOT_FOUND`, `VALIDATION_ERROR`, `INTERNAL_ERROR`, etc.).
- **Dev seed**: `ApplicationRunner` gated by `@Profile("local")` + `app.seed.enabled=true`, upserts `bach-dang-938` row keyed on slug with fixed UUID `00000000-0000-0000-0000-000000000001`; not run in `prod`/`test`.

## Identified risks
- Docker daemon must be running for Compose + Testcontainers — pre-check step; if unavailable, mark verification NOT VERIFIED.
- `JAVA_HOME` env var is broken on this machine — must `set JAVA_HOME=E:\Java\jdk-21` before `mvn`/`mvnw`.
- `pwsh` absent → harness `harness-self-test` gate fails on this box (documented limitation, not a blocker for backend code itself).
- Tags as `text[]` (Postgres array) keeps JPA simple; if admin UI later needs tag taxonomy, migrate to a `tags` table.

## Open questions
- Tag storage: `text[]` vs `tags` join table — chose `text[]` for MVP, revisit when search/faceting is scoped.
- `era` vs `period`: docs use `period`; Flutter mock uses `era`. Keep both columns (`era` canonical; `period` free-text "Mùa Đông 938" label) — confirm with PO.
- Seed UUID for Bach Dang: fixed constant `00000000-0000-0000-0000-000000000001` for stable dev references? Confirm acceptable, else random UUID per env.

## Links
- Task brief: `tasks/TASK-0005/brief.md` (to be created in phase-06)
- Coding rules: `docs/CODING_RULES.md`; DB design: `docs/DATABASE_DESIGN.md`; tech stack: `docs/TECH_STACK.md`
- Flutter contract source: `dau-viet-mobile/lib/mock/models/timeline_models.dart`, `dau-viet-mobile/lib/mock/models/lesson_models.dart` (`HistoricalEventModel`), `dau-viet-mobile/lib/mock/data/mock_bach_dang_data.dart`
