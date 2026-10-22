# Phase 03 — Admin UI: event map locations

## Context links

- `dau-viet-admin/src/features/events/event-form.tsx` — react-hook-form + zod + `apiFetch` + `applyServerFieldErrors` pattern
- `dau-viet-admin/src/features/events/event-editor-page.tsx` — where the locations section plugs in
- `dau-viet-admin/src/lib/dto/event.ts` — DTO conventions (camelCase mirrors backend)
- `dau-viet-admin/src/lib/query-keys.ts` (`qk.events.detail`) — add `qk.mapLocations.list(eventId)`
- `dau-viet-admin/src/components/admin-shell.tsx` — nav structure (no new page needed; section inside event editor)
- `dau-viet-admin/src/lib/api-client.ts`, `api-error.ts`
- `docs/admin-runbook.md` — BFF flow: browser calls `/api/proxy/*` → backend `/api/v1/admin/*`. `apiFetch` already prepends `/api/proxy`, so call paths stay `/admin/...`.

## Overview

- Priority: P1
- Admin module EXISTS (verified): `dau-viet-admin` has full event/lesson/evidence/asset management since TASK-0013. Earlier AGENTS.md note about "uninitialized" is stale.
- Extend the event editor with a "Map locations" section: list + create/edit inline rows + delete + reorder via `displayOrder` field. Keep it inside `EventEditorPage` — no new top-level route (KISS).

## Requirements

- Show existing locations for the event (GET `/admin/events/{id}/map-locations`).
- Add/edit form fields: title, description, latitude, longitude, unlockLessonId (select from lessons of this event), displayOrder, active checkbox.
- `unlockLessonId` options = lessons of the event — already fetchable via `GET /admin/lessons?eventId={id}` (implemented backend; check `src/features/lessons` for an existing lessons query hook to reuse).
- Coordinate client validation: lat -90..90, lng -180..180 (zod `number().min/max` after `coerce`).
- PATCH sends `expectedRowVersion` like `event-form.tsx` does; 409 shows the standard "modified concurrently" banner.
- Server `UNLOCK_LESSON_MISMATCH` (422) surfaces via `toUserMessage` — add a friendly vi message branch in `api-error.ts` if needed, else raw message is fine.

## Files

Create:
- `src/lib/dto/map-location.ts` — `AdminMapLocation`, `MapLocationUpsertRequest`, `MapLocationPatchRequest` mirrors of backend records.
- `src/features/events/map-locations-section.tsx` — the whole section: query list, render table (reuse `components/data-table.tsx` if it fits, else simple list), "Thêm vị trí" dialog (reuse `components/ui/dialog.tsx`), edit dialog, delete with `confirm-dialog.tsx`.

Modify:
- `src/features/events/event-editor-page.tsx` — render `<MapLocationsSection eventId={eventId} />` below `<EventForm>`.
- `src/lib/query-keys.ts` — add `mapLocations: { list: (eventId) => [...] , detail: (id) => [...] }`.
- `src/lib/api-error.ts` — optional friendly mapping for `UNLOCK_LESSON_MISMATCH`.

## Design decisions

- Dialog-based add/edit (not a separate route) — matches evidence-form scale; ~150 LOC section file.
- `displayOrder`: numeric input; no drag-drop (YAGNI; backend sorts asc).
- `active` checkbox maps directly to `active` boolean.
- Delete = hard delete (matches phase-02 backend decision); `confirm-dialog` warns it cannot be undone.
- Lesson select: plain `<select>` (reuse `components/ui/select.tsx` if present — file exists).

## Implementation steps

1. `src/lib/dto/map-location.ts` + query keys.
2. `map-locations-section.tsx`: `useQuery` list; `useMutation` create/patch/delete; `qc.invalidateQueries` on success.
3. Lesson picker: `useQuery` on `GET /admin/lessons?eventId=...&size=100` (existing endpoint, PageResponse shape) → options.
4. Wire into `event-editor-page.tsx`.
5. `npm run lint` + `npm test` in `dau-viet-admin`.

## Todo

- [ ] DTO file
- [ ] query-keys additions
- [ ] `map-locations-section.tsx` (list + dialog form + delete)
- [ ] Wire into event editor page
- [ ] Verify against real backend (manual smoke via admin-runbook flow)

## Success criteria

- Admin can create/edit/delete/activate locations on a DRAFT or PUBLISHED event.
- Setting an unlock lesson from another event returns server 422 and shows an error (UI picker filters to same-event lessons so this should only occur via stale data).
- Concurrent edits → 409 banner consistent with event form.

## Risks

- Lessons list endpoint returns PageResponse — respect `{content: [...]}` shape, not raw array.
- `unlockLessonId` clearing: PATCH with explicit `null` must clear — backend PATCH semantics: use a sentinel? Decision: send `unlockLessonId: null` explicitly when cleared; backend PATCH treats JSON `null` as "set to null" and absent field as "unchanged" — state this requirement in the backend phase (Jackson: use `Optional<T>` or `JsonNullable`; simplest: DTO field as `UUID` + separate `boolean clearUnlockLesson` flag — PICK the flag approach for clarity: `clearUnlockLesson: true` sets null).

## Security considerations

- All calls go through the same-origin BFF (`apiFetch` → `/api/proxy/*`) — role enforced backend-side (`CONTENT_ADMIN`).
- No credentials or tokens in the component.
