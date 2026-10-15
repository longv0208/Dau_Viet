---
title: "TASK-0008 — Historical Event & Lesson Management API"
description: "Admin CRUD + status transitions for events and lessons, read-only lesson templates, JSONB draft editing, optimistic locking, AC-1..AC-7"
status: pending
priority: P1
effort: 14h
branch: main
tags: [backend, admin, events, lessons, jsonb, optimistic-locking]
created: 2026-10-15
---

# TASK-0008 — Historical Event & Lesson Management API

## Context

- Task: `tasks/TASK-0008/task.json` (high-risk; DB/versioning/auth adjacent)
- Schema: V1–V4 already applied. `lessons.draft_json`, `lessons.row_version`, `users.row_version` exist. `historical_events.row_version` does NOT — V5 adds it.
- Existing auth from TASK-0007 (`/api/v1/admin/**` → `hasRole("CONTENT_ADMIN")`) already covers all new endpoints — no security config change needed.
- Public surface `GET /api/v1/events*` stays unchanged (permitAll, published only).

## Phases

| Phase | File | Status | Effort |
|---|---|---|---|
| 01 Shared plumbing (PageResponse reuse, ErrorCodes, V5 migration for `historical_events.row_version`, JPA entities `Lesson`, `LessonTemplate`, `LessonVersion`) | `phase-01-shared-plumbing.md` | pending | 3h |
| 02 Admin Events endpoints (`/api/v1/admin/events`) | `phase-02-admin-events.md` | pending | 3h |
| 03 Admin Lessons endpoints + draft handling (`/api/v1/admin/lessons`) | `phase-03-admin-lessons.md` | pending | 4h |
| 04 Lesson Template read endpoints (`/api/v1/admin/lesson-templates`) | `phase-04-admin-templates.md` | pending | 1h |
| 05 Tests — IT coverage of AC-1..AC-6 incl. optimistic lock concurrency | `phase-05-tests.md` | pending | 2h |
| 06 Docs — `docs/API_SPEC.md`, `task.json` `acEvidence`, brief handoff | `phase-06-docs.md` | pending | 1h |

Sequential order. One writer per file per phase. Phase 05 can start only after 02–04 are green.

## Key design decisions

1. **Draft storage: reuse `lessons.draft_json` (JSONB, default `'{}'`).** No new column needed. Draft edits UPDATE `lessons.draft_json`; publish workflow (TASK-0009 out of scope) reads draft → snapshot_json.
2. **Optimistic locking:** add `@Version` on `HistoricalEvent` + `Lesson`. V5 migration adds `historical_events.row_version BIGINT NOT NULL DEFAULT 0` — single statement, no data backfill needed beyond default.
3. **Status transitions:** enforce DRAFT → PUBLISHED → ARCHIVED, DRAFT → ARCHIVED. No PUBLISHED → DRAFT. No ARCHIVED → anything. Same model for both event and lesson.
4. **No DELETE endpoints.** Brief lists create/list/get/update/publish/archive only. Referenced-event protection is satisfied by refusing to publish/archive an event still referenced by non-archived lessons? — see Open Questions.
5. **Pagination:** reuse `PageResponse<T>` + whitelist-sort pattern from `HistoricalEventController`. Admin list endpoints accept `page/size/sort`, `status` filter, optional `q` search on title/slug for events and title/centralQuestion for lessons.
6. **Validation:** `@Valid` on request records. Business rule violations → domain exceptions mapped by `GlobalExceptionHandler`. New codes: `INVALID_STATUS_TRANSITION`, `EVENT_IN_USE`, `TEMPLATE_NOT_FOUND`, `TEMPLATE_DISABLED`, `LESSON_VERSION_IMMUTABLE`, `EVENT_NOT_FOUND`, `LESSON_NOT_FOUND`, `OPTIMISTIC_LOCK_CONFLICT`.

## Non-goals

- Lesson publish / `lesson_versions` INSERT workflow (TASK-0009).
- Preview, validate, asset upload endpoints.
- DELETE endpoints of any kind.
- Template authoring (read-only here).
- Changes to `com.dauviet.historicalevent` public controller/service — backwards compatible.

## Verification

- `mvnw -q test-compile` after each phase.
- `mvnw verify` requires Docker (Testcontainers). Report `NOT VERIFIED` if Docker is down.
- All 32 existing ITs at base commit `b57e7f2` must stay green.

## Open questions for user

- Forbid archiving a PUBLISHED event when it still has PUBLISHED lessons? Or auto-archive lessons? (Decided: forbid; return 409 `EVENT_IN_USE`. See phase-02 for rationale.)
- Slug uniqueness on update — allow admin to change `slug` post-publish? (Decided: allow while DRAFT; forbid once PUBLISHED — slugs are externally referenced.)
