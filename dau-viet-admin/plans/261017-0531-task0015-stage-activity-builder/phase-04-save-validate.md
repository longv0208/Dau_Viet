# Phase 04 — Save + publish-readiness + template seeding

## Context links

- Save endpoint: `PUT /api/v1/admin/lessons/{id}/draft` (`AdminLessonDraftRequest {draftJson, expectedRowVersion}`).
- Validate endpoint: `POST /api/v1/admin/lessons/{id}/validate` → `PublishReadinessResponse {ready, errors[], warnings[], summary}` — read-only.
- Template list: `GET /api/v1/admin/lesson-templates` returns `{presetJson, schemaVersion, ...}`.
- ApiError envelope: `{code, message, details{errors[{path,code,message}]}, traceId}`.

## Overview

- Priority: P1
- Status: pending
- Effort: 3h
- Goal: wire save button → `PUT /admin/lessons/{id}/draft`; map `DRAFT_SCHEMA_INVALID` `details.errors[]` to validation panel + per-field markers; add "Kiểm tra xuất bản" action hitting `/validate`; add "Tạo cấu trúc từ khung bài học" action that parses template `presetJson` and merges into draft (only when user confirms).

## Key insights

- Save is **whole-document**: serialize current `Draft` → PUT once. `expectedRowVersion` from latest GET.
- `details.errors[]` entries have JSONPath-ish `path` like `stages[2].activities[1].config.question` — map to stage/activity selection + show inline marker.
- On `OPTIMISTIC_LOCK_CONFLICT` (409): prompt reload — do NOT retry silently.
- `validate` is **read-only** and returns publish-readiness; show as separate "Sẵn sàng xuất bản" indicator (chip + collapsible error list); SAVE errors are blocking, publish warnings are informational.
- `presetJson` is opaque: may be `"{}"` or `{stages:[...]}` mirroring draft shape. If `draft.stages.length === 0` AND `template.presetJson` parses to a non-empty stages array → show "Tạo cấu trúc từ khung bài học" primary action; otherwise show as secondary action that requires confirmation (warns it will APPEND stages, never replace — YAGNI).

## Requirements

- `<SaveBar>`: `Lưu nháp` primary button (disabled when `!dirty` or `!canSave`), `Kiểm tra xuất bản` secondary button, `dirty` indicator chip, `lastSaved` timestamp, row-version badge.
- Save flow: `serializeDraft(state.draft)` → `apiFetch(PUT, {draftJson, expectedRowVersion})` → on success update `rowVersion`, `dirty=false`, clear `serverErrors`; on 422 → map `details.errors[]` to `serverErrors` + jump to first failing stage; on 409 → `ConfirmDialog` "Dữ liệu đã được sửa bởi người khác. Tải lại?"; on ARCHIVED → `ErrorState` permanent.
- Validation panel (right pane bottom): list of `{path, code, message}` grouped by stage; clicking scrolls to stage/activity + selects it.
- Path parser: `stages[<i>]` → stage by index; `stages[id=<sid>]` → stage by id; `.activities[<i>]` → activity by index; `.config.<field>` → field marker (for now: highlight the whole activity; per-field highlight only for known editors).
- Publish readiness panel: collapsible card showing `ready` boolean + `errors[]` + `warnings[]` + `summary`; button triggers `useMutation(POST /validate)`; never blocks save.
- Template seeding: `useQuery(qk.templates.list())` → find matching `templateId` → on confirm parse `presetJson` (must be object with `stages` array) → for each stage `genSlugId` rewrite id + regenerate activity ids + clear `nextStageIds` to keep only internal edges remapped via new-id map → dispatch `mergeStages([...])`. If `presetJson` is `"{}"` or unparseable → disable button + tooltip "Khung bài học không có cấu trúc mẫu".

## Architecture

```
BuilderPage
├── SaveBar (top)
├── Navigator | Editor | Inspector
└── Inspector:
    ├── StageTransitionsEditor (nextStageIds checkboxes)
    ├── CompletionEditor (requireAllRequiredStages + requiredStageIds + minScore)
    ├── ValidationPanel (server errors, click-to-jump)
    └── PublishReadinessCard (lazy POST /validate)
```

`nextStageIds` editor: checkbox list of OTHER stages; prevent self-loop; `completion.requiredStageIds` similar checkbox list of required-only stages.

## Related code files

**Create:**
- `src/features/lessons/builder/save-bar.tsx` (~80 LOC)
- `src/features/lessons/builder/inspector-panel.tsx` (~120 LOC)
- `src/features/lessons/builder/transitions-editor.tsx` (~120 LOC)
- `src/features/lessons/builder/completion-editor.tsx` (~100 LOC)
- `src/features/lessons/builder/validation-panel.tsx` (~140 LOC)
- `src/features/lessons/builder/publish-readiness-card.tsx` (~100 LOC)
- `src/features/lessons/builder/template-seed-button.tsx` (~140 LOC — includes presetJson parser)
- `src/lib/dto/publish.ts` — `PublishReadinessResponse` type (~30 LOC)

**Modify:**
- `src/features/lessons/builder/builder-page.tsx` — wire SaveBar + right-pane Inspector; pass save handler.
- `src/features/lessons/builder/use-builder.ts` — add `applyServerErrors(errors)`, `markSaved(rowVersion)`, `mergeStages(stages)` actions.
- `src/lib/api-client.ts` — no change needed (apiFetch generic).
- `src/lib/query-keys.ts` — no change needed (validate is a mutation, not query).

## Implementation steps

1. `save-bar.tsx`: presentational; receives `{dirty, saving, rowVersion, lastSaved, onSave, onValidate}`.
2. `template-seed-button.tsx`: queries templates; parses `presetJson` defensively; remaps ids; confirm dialog before merge.
3. `transitions-editor.tsx`: inside inspector; checkbox list; disabled for self; auto-prune dangling refs on stage delete (already handled by reducer).
4. `completion-editor.tsx`: `requireAllRequiredStages` checkbox + `requiredStageIds` checkbox group (only required stages selectable) + `minScore` number input (optional, 0–100).
5. `validation-panel.tsx`: takes `serverErrors: FieldError[]`; groups by stage path; click → `selectStage`/`selectActivity`.
6. `publish-readiness-card.tsx`: lazy mutation; shows chip + collapsible.
7. Wire everything in `builder-page.tsx`: save handler runs `useMutation` on `apiFetch`; map errors; reload prompt on 409.

## Todo list

- [ ] `save-bar.tsx` + wire in builder-page
- [ ] `use-builder.markSaved/applyServerErrors/mergeStages` actions
- [ ] `validation-panel.tsx` + path-parser + click-to-jump
- [ ] `publish-readiness-card.tsx` lazy `POST /validate`
- [ ] `transitions-editor.tsx` + `completion-editor.tsx`
- [ ] `template-seed-button.tsx` + presetJson parser
- [ ] 409 optimistic-lock reload dialog
- [ ] PUBLISHED status banner + ARCHIVED read-only mode

## Success criteria

- Save round-trip: load existing draft → modify → save → reload → state preserved.
- 422 `DRAFT_SCHEMA_INVALID` populates validation panel; clicking path navigates correctly.
- 409 prompts reload (never silently retries).
- Publish readiness displays without blocking save.
- "Tạo cấu trúc từ khung bài học" appears only when meaningful; merging preserves existing stages and never silently replaces work.
- `status==="PUBLISHED"` shows banner but still allows draft edits; `ARCHIVED` makes builder read-only.

## Risk assessment

- `presetJson` may contain non-conforming shape → defensive parse; log and show toast on failure; never crash.
- Path parser brittleness → keep regex small (`/stages\[(\d+)\]/`, `/stages\[id=([^\]]+)\]/`, `/activities\[(\d+)\]/`); when ambiguous, fall back to selecting the stage only.
- Row-version drift across components — store in reducer, refresh after every save.

## Security considerations

- Save endpoint already requires CONTENT_ADMIN — no new auth surface.
- `presetJson` parse happens client-side only; never sent back to backend.

## Next steps

- Phase 05: tests + docs.
