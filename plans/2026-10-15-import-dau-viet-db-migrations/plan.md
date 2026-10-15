# Plan: Import dau-viet-db Flyway migrations (V2–V4) into backend

## Overview

- Priority: high (unblocks auth, lesson authoring, learner runtime)
- Status: implemented; pending verify on a Docker-enabled host
- Source proposal: `dau-viet-db/` (statically reviewed SQL; see its README for model decisions)

## Context links

- `docs/DATABASE_DESIGN.md` section 5 — sample schema now superseded by real migrations
- `docs/LEARNING_ENGINE_DESIGN.md` — attempts/results/evidence semantics
- `dau-viet-db/README.md` — intentional decisions, out-of-MVP features, open decisions

## Scope of this change

- Copy `V2__users_and_auth.sql`, `V3__authoring_publishing_evidence_assets.sql`, `V4__learner_runtime_progress_rewards.sql` into `dau-viet-backend/src/main/resources/db/migration/`. V1 untouched.
- Extend `FlywayMigrationIT` with assertions that V2–V4 apply cleanly, all 13 new tables exist, and the `lesson_versions` immutability trigger fires on UPDATE.
- Record `dau-viet-db/` source directory in the repo for provenance.
- No JPA entities, repositories or services in this task — schema only. `ddl-auto=validate` only validates mapped entities, so unmapped tables are safe.

## Acceptance criteria mapping

- AC-1 files present, V1 byte-identical -> migration directory listing
- AC-2 schema matches proposal -> `dau-viet-db/` kept as source of truth, diff-verified copies
- AC-3 Flyway applies V1–V4 on empty Postgres -> `FlywayMigrationIT.flywayV2ToV4Applied`
- AC-4 13 new tables exist -> `FlywayMigrationIT.authoringAndRuntimeTablesExist`
- AC-5 immutability trigger enforced -> `FlywayMigrationIT.lessonVersionsAreImmutable`
- AC-6 dev/prod unaffected -> no config/profile change; Flyway runs same migrations everywhere
- AC-7 compile green -> `mvnw -q test-compile` (passed locally; ITs need Docker)

## Risks

- SQL was statically reviewed only; first real `mvnw verify` may surface a dialect issue -> run with Docker before treating as done.
- `ddl-auto=validate` is safe because no entities map the new tables yet; when entities are added, validate them carefully.
- Trigger test relies on per-row BEFORE UPDATE semantics — an UPDATE over zero rows would not raise; the test seeds a real version row first.

## Next steps after verify

- Map JPA entities for `users`/`auth_refresh_tokens` when the auth task starts (TASK-0008+).
- Reconcile `role` naming (`LEARNER`/`CONTENT_ADMIN`) with application code before implementing auth.
