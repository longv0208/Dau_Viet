# TASK-0007 — Import dau-viet-db migrations V2–V4

## Request

User created the MVP PostgreSQL schema proposal at `dau-viet-db/` and asked to read it and bring it into the project.

## What this task does

- Copies V2 (users + refresh tokens), V3 (assets, evidences, lesson templates/lessons/versions), V4 (attempts, idempotency, results, user evidence, rewards) into `dau-viet-backend/src/main/resources/db/migration/`.
- Extends `FlywayMigrationIT` to prove V2–V4 apply, all new tables exist, and the `lesson_versions` immutability trigger works.
- Keeps `dau-viet-db/` in the repo as the proposal source of truth.

## Out of scope

- JPA entities, repositories, services, APIs for the new tables.
- Role-name reconciliation with application code (`LEARNER`/`CONTENT_ADMIN` vs `ADMIN`) — decided at auth task.
- Island/shop/inventory/energy tables — explicitly out of MVP per `dau-viet-db/README.md`.

## Verification status

- `mvnw -q test-compile` passed with `JAVA_HOME=E:\Java\jdk-21`.
- `mvnw verify` (Flyway + Testcontainers ITs) NOT VERIFIED locally — Docker Desktop was not running. Must run on a Docker-enabled host or CI before `done`.
