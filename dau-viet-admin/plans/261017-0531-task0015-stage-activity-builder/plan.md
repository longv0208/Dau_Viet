---
title: "TASK-0015 — Stage & Activity Builder"
description: "Visual editor at /lessons/[id]/builder that authors draftJson via typed forms, saves through PUT /admin/lessons/{id}/draft"
status: pending
priority: P1
effort: 18h
branch: main
tags: [admin, lesson-builder, draft, react-hook-form, msw, playwright]
created: 2026-10-17
---

# Stage & Activity Builder — Implementation Plan

## Goal

`/lessons/[id]/builder` — a 3-pane workspace where Content Admin authors the full `draftJson` document (stages + typed activities) without writing JSON. Saves via `PUT /admin/lessons/{id}/draft` with `expectedRowVersion`. Read-only on published lessons forking a new draft.

## Contract sources

- Backend contract: `plans/reports/planner-261017-0531-task0015-draft-contract.md` (verified against Java).
- Stage/activity types: `DraftSchema.STAGE_ALLOWED_ACTIVITIES` + `ActivityType`/`StageType` enums (12 activity types).
- Save pipeline: `LessonService.updateDraft` → `DraftValidator` SAVE level → `422 DRAFT_SCHEMA_INVALID` with `details.errors[]`.
- ID rule: `^[a-z0-9][a-z0-9-]{1,63}$` — slug-style, NOT UUIDs.

## Phases

| # | Phase | Effort | Status |
|---|---|---|---|
| 01 | Draft model + codec + zod schemas | 3h | pending |
| 02 | Builder shell + stage navigator + stage ops | 4h | pending |
| 03 | Activity picker + typed editors (READ/VIEW_IMAGE/MC/EVIDENCE_SELECT/MATCHING/DRAG_ORDER/CER + 5 fallbacks) | 5h | pending |
| 04 | Save + validate + publish-readiness indicator + presetJson instantiation | 3h | pending |
| 05 | Tests (vitest + playwright stub) + docs | 3h | pending |

## Key design choices

- **Whole-document save**: builder keeps one typed `Draft` model in memory; serialize → PUT once. No per-stage PATCH calls (keeps optimistic-lock story simple).
- **Spread-through codec**: `parseDraft` → TS types → `serializeDraft` preserves unknown top-level keys (`objectives`, future fields) by carrying them in a `rest` bag, never whitelist-dropping.
- **IDs generated client-side**: `crypto.randomUUID()` fails ID_PATTERN — generate `stage-<rand>` / `act-<rand>` slugs (verify pattern, ensure uniqueness within draft).
- **Stage→activity allow-map drives the picker**: selecting stage type filters available `ActivityType`s (READ always allowed).
- **Template seeding is client-side**: `presetJson` is opaque; if non-empty and draft is empty, offer explicit "Tạo cấu trúc từ khung bài học" button — never silent.
- **Publish readiness**: separate call to `POST /admin/lessons/{id}/validate`; shown as informational chip + error list. Save button never blocks on publish errors.
- **Published lesson**: if `status==="PUBLISHED"` show banner "Thay đổi sẽ tạo bản nháp mới; phiên bản đã xuất bản không bị ảnh hưởng".
- **Unknown activity fields preserve on edit**: editors read known config keys into form fields; on save merge form state back over the original `config`/`validation`/`feedback` (spread, not replace) so authoring in builder never silently drops fields the editor doesn't know.

## File layout

```
src/features/lessons/builder/
├── builder-page.tsx                 # top-level 3-pane layout + data wiring
├── draft-model.ts                   # TS types + parse/serialize (spread-through)
├── draft-schemas.ts                 # zod schemas per stage/activity type
├── draft-id.ts                      # slug-style id generator
├── stage-navigator.tsx              # left pane
├── stage-editor.tsx                 # middle pane (single stage)
├── stage-inspector.tsx              # right pane (nextStageIds, completion)
├── activity-picker.tsx              # type picker w/ Vietnamese labels + icons
├── activity-editors/
│   ├── read-editor.tsx
│   ├── view-image-editor.tsx
│   ├── multiple-choice-editor.tsx
│   ├── evidence-select-editor.tsx
│   ├── matching-editor.tsx
│   ├── drag-order-editor.tsx
│   ├── cer-editor.tsx
│   └── unsupported-editor.tsx       # honest fallback
├── use-builder.ts                   # reducer + dirty tracking + save logic
└── validation-panel.tsx             # server field-error list
```

## Reuse from TASK-0014

- `apiFetch`, `ApiClientError`, `qk.lessons.detail`
- `useUnsavedChangesGuard`, `confirmDiscard`
- `EmptyState`, `ErrorState`, `PageHeader`, `StatusChip`, `ConfirmDialog`
- `Input`, `Textarea`, `Select`, `Button`, `Label`, `Card`
- `react-hook-form` + `zod` + `useFieldArray`
- MSW `handlers.ts` extension for `PUT /admin/lessons/:id/draft` + `POST /admin/lessons/:id/validate`
- Playwright stub: extend `scripts/e2e-backend-stub.mjs` for both endpoints.

## Risks

- **presetJson shape unknown**: real templates may carry non-empty presetJson with structure different from what we synthesize. Mitigation: defensive parser — only accept `{schemaVersion:1, stages:[…]}` shape; otherwise offer the action but warn on failure.
- **`onPartial`/`onContradicted` gap**: backend resolver reads them but DraftSchema does not allow them in `ACTIVITY_KEYS`. Do not emit; flag in report.
- **Evidence/asset pickers**: no catalogue UI available — free-text UUID input + warning label, document TASK-0016 dependency.
- **File size**: typed editors + forms grow fast. Hard-split at ~200 LOC/file; per-activity editor in own file.

## Open questions

- VERIFICATION activity's transition fields (`onPartial`/`onContradicted`) — backend schema gap; emit only after DraftSchema allows them (separate fix task).
- Whether to expose `validation`/`feedback` blocks in the typed editors or leave as raw JSON (recommend leaving JSON-only with a small "advanced" disclosure).

## Phase files

- `phase-01-draft-model.md` — types, codec, zod schemas, id generator
- `phase-02-stage-shell.md` — page, layout, navigator, stage ops
- `phase-03-activity-editors.md` — picker + 7 typed editors + fallback
- `phase-04-save-validate.md` — save pipeline, publish readiness, template seeding
- `phase-05-tests.md` — vitest + playwright extension + docs
