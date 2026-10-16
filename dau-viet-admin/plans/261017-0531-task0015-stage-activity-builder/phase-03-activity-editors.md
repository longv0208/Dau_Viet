# Phase 03 — Activity picker + typed editors

## Context links

- Backend validators: `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/validators/SimpleActivityValidators.java`, `MultipleChoiceValidator.java`
- Contract: `plans/reports/planner-261017-0531-task0015-draft-contract.md` §4 (per-type config table)
- Stage→activity allow-map: `DraftSchema.STAGE_ALLOWED_ACTIVITIES` (mirror in `draft-model.ts`).

## Overview

- Priority: P1
- Status: pending
- Effort: 5h
- Goal: middle-pane `StageEditor` lists activities in the selected stage + `<ActivityPicker>` offers only types allowed for that stage's `StageType`; 7 typed editors (READ, VIEW_IMAGE, MULTIPLE_CHOICE, EVIDENCE_SELECT, MATCHING, DRAG_ORDER, CER) + `unsupported-editor` fallback for the remaining 5.

## Key insights

- Filter by `STAGE_ALLOWED_ACTIVITIES[stage.type]` — never offer a type the backend would reject with `STAGE_ACTIVITY_MISMATCH`. READ is always present.
- Every editor is an isolated RHF sub-form mounted on activity select; save on "Áp dụng" merges form output back over the original activity's `config`/`validation`/`feedback` (spread, not replace) — fields the editor doesn't model survive.
- `config` is authoring-only. Don't render `correctOptionIds`/`correctPairs`/`expectedOrder`/`requiredEvidenceIds`/`expectedHypothesis` etc. as learner-facing preview (they're stripped before learner).
- For MATCHING/DRAG_ORDER item ids — auto-generate stable slugs (`it-<rand4>`); user sees labels, not ids.
- VERIFICATION activity's `onPartial`/`onContradicted` transition fields are NOT in `ACTIVITY_KEYS` — do NOT emit them; show `unsupported-editor` for VERIFICATION until backend schema is extended.

## Requirements

### Typed editors

| Type | Form fields |
|---|---|
| READ | `instruction?`, `required?`, `config.text: string` (Markdown/plain) |
| VIEW_IMAGE | `instruction?`, `required?`, `config.imageAssetId: string` (UUID), `config.caption?: string` |
| MULTIPLE_CHOICE | `instruction?`, `required?`, `config.question`, `config.options[]: {id,label}` (≥2), `correctOptionIds[]` (single OR multi — choose via radio "Một đáp án"/"Nhiều đáp án"), `config.maxAttempts?: number` |
| EVIDENCE_SELECT | `instruction?`, `required?`, `config.visibleEvidenceIds[]: UUID[]` (textarea free-input — one UUID per line), `config.minRequired?: number` |
| MATCHING | `instruction?`, `required?`, `config.pairs[]: {left:{id,label}, right:{id,label}}` (≥2), auto-emit `config.correctPairs` mirroring pairs array |
| DRAG_ORDER | `instruction?`, `required?`, `config.items[]: {id,label}` (≥2, ↑/↓ move), auto-emit `config.expectedOrder = items[].id` |
| CER | `instruction?`, `required?`, `config.rubric.criteria[]: string` (≥1 non-empty), `config.requiredEvidenceIds[]` (UUID textarea) |

### Fallback

`unsupported-editor.tsx` — shows a card: "Loại hoạt động {type} chưa có trình soạn trực quan; sửa JSON thủ công nếu cần." + read-only `<Textarea>` of the raw `config` (preserved on save, no validation UI). Used for EXPLORE_MAP, REASONING_CONNECT, HYPOTHESIS_CHOICE, VERIFICATION, REFLECTION_PROMPT (until individually supported — REFLECTION_PROMPT is a 5-min upgrade: just `prompt` string; implement if trivial).

## Architecture

```
StageEditor (selected stage)
├── Stage header (title, type, required toggle)
├── ActivityList (rows w/ reorder + delete + edit select)
├── "Thêm hoạt động" → ActivityPicker (filtered by stage.type)
└── ActivityEditorHost (mounts typed editor for selectedActivityId)
```

Per-activity editor: own RHF form initialized from `activity` object; on submit dispatch `updateActivity(stageId, activityId, next)` where `next = {...activity, ...formOutput, config: {...activity.config, ...formConfig}}`.

## Related code files

**Create:**
- `src/features/lessons/builder/stage-editor.tsx` (~150 LOC)
- `src/features/lessons/builder/activity-list.tsx` (~120 LOC)
- `src/features/lessons/builder/activity-picker.tsx` (~120 LOC)
- `src/features/lessons/builder/activity-editors/read-editor.tsx` (~80 LOC)
- `src/features/lessons/builder/activity-editors/view-image-editor.tsx` (~80 LOC)
- `src/features/lessons/builder/activity-editors/multiple-choice-editor.tsx` (~200 LOC — the biggest)
- `src/features/lessons/builder/activity-editors/evidence-select-editor.tsx` (~120 LOC)
- `src/features/lessons/builder/activity-editors/matching-editor.tsx` (~180 LOC)
- `src/features/lessons/builder/activity-editors/drag-order-editor.tsx` (~150 LOC)
- `src/features/lessons/builder/activity-editors/cer-editor.tsx` (~140 LOC)
- `src/features/lessons/builder/activity-editors/reflection-prompt-editor.tsx` (~60 LOC, easy win)
- `src/features/lessons/builder/activity-editors/unsupported-editor.tsx` (~70 LOC)
- `src/features/lessons/builder/activity-editors/index.ts` (~40 LOC — registry)

## Implementation steps

1. `activity-picker.tsx`: Dialog grid of allowed types from `STAGE_ALLOWED_ACTIVITIES[stage.type]`; tile = icon + Vietnamese label + short explanation (from `labels.ts`); on pick → `addActivity` with empty config + auto-generated id; auto-select new activity.
2. `activity-list.tsx`: rows with drag-handle icon (visual only), type tag, title (instruction first 40 chars or id), required dot; reorder ↑/↓; per-row delete `ConfirmDialog`.
3. Per-editor files: RHF + `useFieldArray` for arrays; on submit dispatch update; on "Reset" restore original.
4. `unsupported-editor.tsx`: read-only JSON viewer + textarea (editable but unvalidated — write back as `config` parse attempt; on parse error keep original and warn).
5. Registry `index.ts`: `const EDITORS: Record<ActivityType, ComponentType<EditorProps>>` — fallback to `UnsupportedEditor`.

## Todo list

- [ ] `activity-picker.tsx` filtered by stage type
- [ ] `activity-list.tsx` w/ reorder + delete
- [ ] 7 typed editors + REFLECTION_PROMPT + unsupported fallback
- [ ] `stage-editor.tsx` mounts list + picker + active editor
- [ ] `use-builder` actions: `addActivity`, `updateActivity`, `reorderActivities`, `removeActivity`, `selectActivity`
- [ ] `required` checkbox disabled when `stage.required === false` (backend publish rejects `REQUIRED_IN_OPTIONAL_STAGE`; SAVE allows it but UI warns)
- [ ] MC editor: "Một đáp án" → `correctOptionIds` (≤1); "Nhiều đáp án" → `multiCorrect` (≥1); switch clears other field — never emit both
- [ ] MATCHING: pairs[] auto-emit `correctPairs` matching left.id↔right.id
- [ ] DRAG_ORDER: item list is the order → `expectedOrder` auto-mirror

## Success criteria

- Stage editor lists activities; "Thêm hoạt động" offers only allowed types.
- Editing each supported type produces backend-valid `config` (verified by zod schema).
- Unsupported types show honest placeholder + raw JSON view; saving preserves existing config.
- Selecting optional stage disables/warns on `required` activity toggle.

## Risk assessment

- RHF + dynamic editors: keep each editor's `defaultValues` computed from `activity` once on mount (`useMemo`); switching activities must reset the form (`form.reset(next)` in `useEffect` keyed on `activityId`).
- `correctOptionIds` vs `multiCorrect` mutual exclusivity — radio-group drives which field is emitted; validate via `MultipleChoiceConfig` refine.

## Security considerations

- Editor UI labels `correctOptionIds`/`correctPairs`/`expectedOrder` as "đáp án đúng (không hiển thị cho học viên)" — explicit authoring-only.
- Never log activity `validation`/`correct*` content.

## Next steps

- Phase 04 wires save pipeline + publish readiness indicator + template seeding.
