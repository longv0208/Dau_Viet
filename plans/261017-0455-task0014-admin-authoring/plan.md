# TASK-0014 — Admin Authoring (Events + Lessons)

Status: implemented (pending review) · Owner: claude · Risk: high

Gates (2026-10-17): vitest 36/36 · tsc clean · next lint clean · next build pass · playwright 5/5 (login + authoring specs vs node:http stub)

## Backend contracts (verified verbatim from Java source)

- `POST /api/v1/admin/events` → `AdminEventCreateRequest{slug*,title*,era,period,startYear,summary*,description,location,coverAssetKey,tags}` (slug kebab-case, summary required)
- `PATCH /api/v1/admin/events/{id}` → same fields + `expectedRowVersion`; null = unchanged
- `GET /api/v1/admin/events` → `PageResponse<AdminEventSummaryResponse>` (id,slug,title,era,startYear,status,tags); params `page,size,sort,status,q`; sort whitelist `title,slug,startYear,createdAt,updatedAt,status`
- `POST /{id}/publish`, `POST /{id}/archive` — out of scope for UI this task
- `GET /api/v1/admin/lesson-templates` → plain `List<LessonTemplateResponse>` (enabled only)
- `POST /api/v1/admin/lessons` → `AdminLessonCreateRequest{eventId*,templateId*,title*,centralQuestion*,objectivesJson,draftJson}`
- `GET /api/v1/admin/lessons` → `PageResponse<AdminLessonSummaryResponse>`; params `page,size,sort,eventId,status,q`
- `GET /api/v1/admin/lessons/{id}` → `AdminLessonResponse` (adds templateId,objectivesJson,draftJson,rowVersion,audit)
- `PATCH /api/v1/admin/lessons/{id}` → `AdminLessonUpdateRequest{templateId,title,centralQuestion,objectivesJson,expectedRowVersion}` (templateId only while DRAFT)
- Error envelope: `{code,message,details,traceId}`; validation → `VALIDATION_ERROR` + `details[field]=msg`; optimistic lock → `OPTIMISTIC_LOCK_CONFLICT` 409; invalid transition → `INVALID_STATUS_TRANSITION` 409.

## Routes (App Router)

- `/events` — list (extends existing).
- `/events/new` — create form.
- `/events/[id]` — edit form.
- `/lessons` — list (extends existing).
- `/lessons/new` — wizard `/lessons/new?event=<id>` supported (pre-select event).
- `/lessons/[id]` — basic editor (title/centralQuestion/objectives/event/template view). Stage builder link shows "Sắp triển khai".

## File plan (kebab-case, ≤200 LOC/file where practical)

- `src/lib/dto/event.ts` — add `AdminEventDetail`, `AdminEventCreateRequest`, `AdminEventUpdateRequest`.
- `src/lib/dto/lesson.ts` — add `AdminLessonDetail`, `AdminLessonCreateRequest`, `AdminLessonUpdateRequest`; `objectivesJson` helpers.
- `src/features/events/event-form.tsx` — shared create/edit form (RHF+zod).
- `src/features/events/event-editor-page.tsx` — client page wrapping form for edit.
- `src/app/(admin)/events/new/page.tsx`, `src/app/(admin)/events/[id]/page.tsx` — route entries.
- `src/features/lessons/lesson-wizard.tsx` — 4-step wizard (event select, template select, basic info, confirm+save).
- `src/features/lessons/lesson-basic-form.tsx` — A-07 edit form.
- `src/features/lessons/lesson-editor-page.tsx` — loads lesson + renders form + status chip + "Sắp triển khai" stage-builder card.
- `src/app/(admin)/lessons/new/page.tsx`, `src/app/(admin)/lessons/[id]/page.tsx`.
- `src/components/unsaved-changes-guard.tsx` — beforeunload + route-change guard (simple version: beforeunload only; in-app nav uses browser confirm via `window.confirm` wrapped in a custom hook).
- `src/lib/query-keys.ts` — add `events.detail`, `lessons.detail`, `lessons.list` filters.
- MSW handlers + fixtures for create/get/update endpoints.
- Tests: `event-form.test.tsx`, `lesson-wizard.test.tsx`, `lesson-basic-form.test.tsx`; Playwright `authoring.spec.ts`.

## Key decisions

- **objectivesJson**: UI uses a dynamic list of text inputs (min 1); serialized to JSON array of strings on submit; parsed back when editing. No raw JSON shown.
- **draftJson**: for TASK-0014 the wizard sends `"{}"` (server default). Stage Builder (TASK-0015) owns it.
- **Template rebinding**: only while DRAFT — editor shows template name read-only.
- **Unsaved-changes**: `beforeunload` + intercept Link clicks on the same page via a thin wrapper (`useUnsavedGuard(isDirty)`). KISS, no router monkey-patching.
- **Slug**: auto-suggest from title (kebab-case ASCII-folded); editable. Backend enforces pattern.
- **Optimistic lock**: PATCH sends `expectedRowVersion` from the loaded detail.
- **Event filter on lessons**: a select populated from `GET /admin/events?size=100` (admin scale acceptable for MVP).
- **Bạch Đằng test**: Playwright scenario uses generic UI, no hardcoded slug — test data comes from the stub.

## Out of scope (explicit)

Stage builder, activity editor, evidence, media upload, publish/archive UI, preview, versions list UI. The editor links to those with "Sắp triển khai" placeholders.
