# Phase 02 — Builder shell + stage navigator + stage ops

## Context links

- Page pattern: `src/app/(admin)/lessons/[id]/page.tsx` (existing basic editor) — builder lives at sibling route `src/app/(admin)/lessons/[id]/builder/page.tsx`.
- Layout patterns: `src/components/admin-shell.tsx`, `PageHeader`, `EmptyState`, `ErrorState`.
- State pattern: `src/features/lessons/lesson-basic-form.tsx` (TanStack Query + RHF + dirty tracking).

## Overview

- Priority: P1
- Status: pending
- Effort: 4h
- Goal: route + 3-pane responsive layout + left-pane stage navigator + stage CRUD (add/rename/retype/reorder/delete/duplicate) + `useBuilder` reducer holding the whole `Draft` in memory.

## Key insights

- Whole-document editing: one in-memory `Draft` reducer; mutations dispatch actions (`addStage`, `updateStage`, `reorderStages`, `removeStage`, `duplicateStage`, `selectStage`, `addActivity`, …). Save serializes whole doc to `PUT /admin/lessons/{id}/draft` once — no per-stage PATCH.
- Stage reorder → array order changes (matches backend order semantics).
- Stage delete must also prune `nextStageIds` refs + `completion.requiredStageIds` (mirrors `LessonDraftService.removeStage`).
- Mobile: navigator collapses to a top tab strip; middle pane dominant; inspector becomes bottom sheet or drawer.

## Requirements

- Route: `app/(admin)/lessons/[id]/builder/page.tsx`. Server component that loads `lessonId` then renders `<BuilderPage lessonId={id}/>` client component.
- `<BuilderPage>`: `useQuery(qk.lessons.detail(id))` → `parseDraft(draftJson)` → `useReducer`. Show `EmptyState` while loading, `ErrorState` on 404, warning banner if `status==="PUBLISHED"` or `ARCHIVED` (read-only mode).
- Layout: CSS grid `grid-cols-[280px_1fr_320px]` desktop; `md:` collapse to 1-col with tab strip; `lg:` re-show. Tailwind classes only, no JS measurement.
- Stage navigator (left):
  - List stage chips: title (or id fallback), type tag, required dot, activity count.
  - Reorder via up/down arrows (no dnd lib needed for MVP — KISS).
  - Add stage → opens type picker modal (`StageType` Select with Vietnamese labels).
  - Per-stage menu: rename (inline edit), retype, duplicate, delete (ConfirmDialog).
- Middle pane placeholder for stage editor (phase 03 fills).
- Right pane placeholder for inspector (phase 04).
- Unsaved-changes guard wired to reducer `dirty` flag.

## Architecture

```
BuilderPage
├── useBuilderReducer (state: draft, selection, dirty, errors)
├── StageNavigator (left)
├── StageEditorHost (middle — mounts active stage's editor)
└── InspectorHost (right — transitions, completion, validation)
```

Reducer actions are pure; `useBuilder` exposes stable action dispatchers. Server validation errors land in `state.errors` (path → message) for the validation panel.

## Related code files

**Create:**
- `src/app/(admin)/lessons/[id]/builder/page.tsx` — thin route (~30 LOC)
- `src/features/lessons/builder/builder-page.tsx` — root client component (~150 LOC)
- `src/features/lessons/builder/use-builder.ts` — reducer + actions (~180 LOC)
- `src/features/lessons/builder/stage-navigator.tsx` — left pane (~180 LOC)
- `src/features/lessons/builder/stage-type-picker.tsx` — modal (~80 LOC)
- `src/features/lessons/builder/labels.ts` — Vietnamese labels for StageType/ActivityType + lucide icons (~120 LOC)

**Modify:**
- `src/app/(admin)/lessons/[id]/page.tsx` — add "Mở Builder" button/link.
- `src/features/lessons/lessons-table.tsx` — add Builder row action (optional; defer if scope).

## Implementation steps

1. `labels.ts`: maps `StageType`/`ActivityType` → `{label, description, icon}`. Vietnamese text. Reused by pickers + inspector.
2. `use-builder.ts`: `DraftState = {draft: Draft, selectedStageId: string|null, selectedActivityId: string|null, dirty: boolean, serverErrors: FieldError[], savedRowVersion: number}`; actions for stage CRUD + activity CRUD (forward-only); selector `selectedStage`.
   - Delete stage: filter `nextStageIds` + `completion.requiredStageIds` of all stages.
   - Duplicate stage: deep-copy with new slug ids for stage AND activities (`genSlugId` per item); insert after original.
3. `stage-navigator.tsx`: list + add button + per-row menu (rename inline, retype modal, duplicate, delete confirm). Reorder via ↑/↓ icons.
4. `stage-type-picker.tsx`: shadcn Dialog listing all 9 StageTypes w/ label + description; on pick, dispatch `addStage({type, title: label})`.
5. `builder-page.tsx`: fetch, reducer wiring, layout, header w/ save button (save logic stub for now — phase 04 finishes), unsaved-changes guard, loading/error/empty branches.
6. Route + nav links from lesson detail page.

## Todo list

- [ ] `labels.ts` Vietnamese strings + icons for all 9 stage types, 12 activity types
- [ ] `use-builder.ts` reducer + actions (stage + activity stubs)
- [ ] `stage-type-picker.tsx` modal
- [ ] `stage-navigator.tsx` with reorder/add/rename/retype/duplicate/delete
- [ ] `builder-page.tsx` + route file
- [ ] "Mở Builder" link on lesson detail
- [ ] Unsaved-changes guard + ConfirmDialog on delete
- [ ] Lint + tsc clean

## Success criteria

- Route `/lessons/{id}/builder` opens with empty draft for a new lesson.
- Stages can be added/renamed/retyped/reordered/duplicated/deleted; navigator reflects state immediately.
- Deleting a stage prunes `nextStageIds` references.
- Responsive: 3-pane on lg+, stacked on md, collapsible navigator on sm.

## Risk assessment

- Reducer state grows — split `use-builder` if it crosses 200 LOC (extract per-domain actions).
- Inline rename UX on small screens — fallback to popover input.

## Security considerations

- All edits are client-side until explicit save; no auto-save (avoid surprising row-version conflicts).
- Optimistic-lock `expectedRowVersion` sent on save → 409 → prompt user to reload.

## Next steps

- Phase 03 mounts `<ActivityPicker>` + typed editors in middle pane.
