# TASK-0021 — Historical Map & Location Unlock (FR-35..38)

Implementation plan. Status: draft, ready for implementation.

## Scope

New domain `MapLocation` attached to `HistoricalEvent`, learner-facing
map APIs, admin CRUD for locations inside the existing event editor, and a
Flutter `HistoricalMapScreen` with unlock states driven by server-computed
learner completion.

Out of scope: rewards/EXP/economy, EXPLORE_MAP activity engine changes,
geocoding, paid map tiles, admin bootstrapping beyond the minimal map-location
form.

## Resolved unknowns (decisions taken)

- Completed status = `learner_attempts.status = 'COMPLETED'` (enum
  `LearnerAttemptStatus`, `dau-viet-backend/.../learning/domain/LearnerAttemptStatus.java`).
  Unlock rule: exists >= 1 COMPLETED attempt whose pinned `lesson_version_id`
  belongs to `unlock_lesson_id` — any version, survives republish.
- Event published-visibility = `historical_events.status = 'PUBLISHED'`
  (`EventStatus` enum; `HistoricalEventService` already filters this way).
- `dau-viet-admin` IS bootstrapped (TASK-0013+): Next.js under `src/app/(admin)`,
  event editor at `src/features/events/event-form.tsx` + `event-editor-page.tsx`.
  Admin phase extends this — not a blocker.
- Flutter map deps: none present (`pubspec.yaml` has no `flutter_map`).
  RECOMMENDATION: custom `CustomPainter` parchment-style map (stylized, not
  geographic tiles) — zero new deps, on-brand with Dong Son/parchment theme,
  avoids OSM tile licensing complexity; positions derived from lat/lng
  normalized into a hand-drawn VN coastline illustration. This matches the
  brief's "or simpler custom painter" fallback and keeps YAGNI.
- Seed data: no hard-coded coordinates — locations are admin-configured only;
  demo/mock mode uses fixture data inside the mock repository, not seed SQL.

## Phases

| # | Phase | Status | Depends on |
|---|-------|--------|------------|
| 01 | Backend domain + Flyway V8 | pending | — |
| 02 | Backend learner map API | pending | 01 |
| 03 | Admin event map-locations UI | pending | 01 (API contract), backend admin endpoints in 02 |
| 04 | Flutter map screen + navigation | pending | 02 |
| 05 | Mock data + tests | pending | 02, 04 |
| 06 | Docs | pending | all |

## Key files (existing, to modify)

Backend (package root `dau-viet-backend/src/main/java/com/dauviet/`):
- `historicalevent/domain/HistoricalEvent.java` (unchanged; new sibling entity `MapLocation`)
- `common/config/SecurityConfig.java` — `/api/v1/map/**` already falls under `anyRequest().authenticated()`; add explicit comment only
- `common/error/GlobalExceptionHandler.java` — add `MAP_LOCATION_NOT_FOUND` handler if a dedicated exception is used
- `db/migration/V8__map_locations.sql` (new)

Admin (`dau-viet-admin/src/`):
- `features/events/event-form.tsx`, `event-editor-page.tsx`, `lib/dto/event.ts`, `lib/query-keys.ts`

Mobile (`dau-viet-mobile/lib/`):
- `app/router.dart` — add `/map` route
- `features/dashboard/presentation/learner_dashboard_screen.dart` — add map entry point (shortcut card + bottom-nav retarget optional)
- `features/map/` (new feature dir)

## Invariants honored

- Server-authoritative unlock: computed from `learner_attempts` server-side;
  client never sends userId/completion flags.
- Published versions immutable; unlock reads attempts pinned to ANY published
  version of the linked lesson.
- No answer-key/validation leaks: locked locations return preview + required
  lesson metadata only.
- Read-only map endpoints need no idempotency; admin mutations are plain
  CRUD + `expectedRowVersion` where applicable.
- Per-learner isolation: unlock state scoped to `sub` of JWT.
