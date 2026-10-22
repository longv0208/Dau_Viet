# Phase 06 — Documentation updates

## Context links

- `docs/API_SPEC.md` — endpoint tables + "Notes đã chốt TASK-xxxx" convention
- `docs/DATABASE_DESIGN.md` — section 3 table list + "Trạng thái áp dụng" line listing migrations
- `docs/PROJECT_OVERVIEW.md` — section 6 "Đã code / chưa code" table includes a Historical Map row to update
- `docs/PROGRESS.md` — generated from task JSON; update only via task.json status (do not hand-edit per AGENTS.md)
- `AGENTS.md` — markdown plain headings, no decorative icons

## Overview

- Priority: P1 — required for handoff; small diff.
- Update contract + schema docs to reflect implemented map domain; no new doc files.

## Changes

### `docs/API_SPEC.md`

Section 2 learner table — append rows:

| GET | `/map/locations` | Map locations of published events + per-learner unlockState — implemented TASK-0021; authenticated |
| GET | `/map/locations/{id}` | Location detail; LOCKED returns preview + requiredLesson only — implemented TASK-0021 |

Section 3 admin table — append:

| POST | `/admin/events/{eventId}/map-locations` | Create map location — implemented TASK-0021 |
| GET | `/admin/events/{eventId}/map-locations` | List locations of an event — implemented TASK-0021 |
| GET | `/admin/map-locations/{id}` | Location detail — implemented TASK-0021 |
| PATCH | `/admin/map-locations/{id}` | Update (`expectedRowVersion`, `clearUnlockLesson`) — implemented TASK-0021 |
| DELETE | `/admin/map-locations/{id}` | Delete location (hard delete; no snapshot refs) — implemented TASK-0021 |

Add "Notes đã chốt TASK-0021 (Historical Map)" block covering:

- Unlock rule semantics (COMPLETED attempt on ANY published version of `unlock_lesson_id`; NULL → AVAILABLE; else LOCKED).
- Locked payload contract (preview fields + `requiredLesson{lessonId,title}` only).
- New error codes `MAP_LOCATION_NOT_FOUND` (404), `UNLOCK_LESSON_MISMATCH` (422).
- Coordinate ranges; admin-configured only; no geocoding.
- `/map/**` requires authentication (any role).

### `docs/DATABASE_DESIGN.md`

- Section 3 table: add `map_locations` row — fields `id, event_id, title, description, latitude, longitude, unlock_lesson_id, display_order, active, timestamps, row_version`.
- "Trạng thái áp dụng" line: extend to mention V8 (`map_locations`).
- ERD mermaid: add `HISTORICAL_EVENTS ||--o{ MAP_LOCATIONS : places` and `LESSONS ||--o{ MAP_LOCATIONS : unlocks` (nullable).

### `docs/PROJECT_OVERVIEW.md`

- Section 6 "Đã code" column: move Historical Map row from right column to left with "(FR-35–38, TASK-0021)" note.

### Admin runbook

`docs/admin-runbook.md` — one line under the events section noting the map-locations sub-resource exists inside the event editor.

## Todo

- [ ] API_SPEC learner + admin tables + TASK-0021 notes block
- [ ] DATABASE_DESIGN table row + migration line + ERD edges
- [ ] PROJECT_OVERVIEW status row
- [ ] admin-runbook one-liner

## Success criteria

- Contract docs match implemented endpoints/fields/error codes exactly.
- No new markdown files; plain headings only.

## Risks

- PROGRESS.md is generated — leave it; task.json drives it.
