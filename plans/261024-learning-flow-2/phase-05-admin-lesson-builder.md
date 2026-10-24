# Phase 05 — Admin Lesson Builder (Authoring UI)

## Context Links
- plan: `plans/261024-learning-flow-2/plan.md`
- `dau-viet-admin/src/features/lessons/builder/draft-model.ts`
- `dau-viet-admin/src/features/lessons/builder/activity-editors/` (index.tsx registry, shared-fields.tsx, evidence-ref-picker.tsx, feedback-panel.tsx)
- `dau-viet-admin/src/features/lessons/builder/labels.ts`
- `dau-viet-admin/src/features/lessons/preview/renderers/` (assessment-renderers.tsx, choice-renderers.tsx)
- `dau-viet-admin/src/features/lessons/builder/publish-readiness-card.tsx`

## Overview
- Priority: P1
- Status: pending
- Depends on: phase 01 (contract frozen). Can run parallel to phases 02–04.
- Let a non-coder author CER_CHOICE and graded EVIDENCE_SELECT/REASONING_CONNECT
  with answer keys + feedback — pickers and toggles only, no raw JSON editing.

## Key Insights
- Editors follow `EditorProps` contract (`shared-fields.tsx`) and register in
  `activity-editors/index.tsx` `EDITORS` map; unsupported types fall back to
  `UnsupportedEditor`.
- `EvidenceRefPicker` already provides event-scoped evidence multi-select —
  reuse for `evidenceOptions`/`acceptedEvidenceIds`.
- `FeedbackPanel` manages per-outcome feedback text — reuse for
  COMPLETED/PARTIAL/INCORRECT/EXHAUSTED keys.
- Round-trip rule (`draft-model.ts` header): unknown keys preserved via
  `...rest` — new config fields survive untouched.
- Preview renderers are pure presentational; adding a CER_CHOICE preview is a
  new renderer + dispatch entry.

## Requirements

### `cer-choice-editor.tsx` (new)
- `ActivityCommonFields` (id/instruction/required).
- Claims list editor: text rows + add/remove (≥2) writing
  `config.claims[{id,text}]` (ids auto-slugged like existing editors do —
  check `draft-id.ts`/`genSlugId`).
- "Accepted claims" = checkbox group over claims → `acceptedClaims[]`.
- `evidenceOptions` via `EvidenceRefPicker` (event evidence multi-select).
- "Accepted evidence" = checkbox group over chosen evidenceOptions →
  `acceptedEvidenceIds[]`.
- Reasoning list editor + "accepted reasoning" checkboxes →
  `reasoningOptions`/`acceptedReasoningIds`.
- `priorEvidenceSource` = dropdown of the draft's EVIDENCE_SELECT activity ids
  (from `draft.stages` — pass draft via EditorProps; check `EditorProps`
  signature — if it lacks draft access, thread it through `ActivityEditor`
  call site in `stage-editor.tsx`).
- `maxAttempts`, `minCorrect` numeric inputs.
- `FeedbackPanel` wired for COMPLETED/PARTIAL/INCORRECT/EXHAUSTED.
- `graded` fixed `true` (CER_CHOICE is always graded) — write it on create.

### Graded toggles in existing editors
- `evidence-select-editor.tsx`: "Chấm điểm theo đáp án (graded)" switch →
  `config.graded`; when on, show `EvidenceRefPicker` for `acceptedEvidenceIds`
  (subset of visibleEvidenceIds, client-side hint) + `maxAttempts` input.
- `reasoning-connect-editor.tsx`: same switch → `config.graded`; when on, show
  a relations builder for `expectedRelations` (from-node/relation/to-node
  dropdowns populated from authored `nodes` + `allowedRelations`) +
  optional additional accepted sets editor (or defer acceptedRelationSets UI —
  MVP: expectedRelations only, note acceptedRelationSets is JSON-advanced).

### Wiring
- `activity-editors/index.tsx`: `CER_CHOICE: CerChoiceEditor`.
- `draft-model.ts`, `labels.ts` (phase 01).
- `activity-picker.tsx`: no change (drives off allowlist).
- `use-builder.ts` `createActivity` (or equivalent factory): add default
  config template for `CER_CHOICE` (`{graded:true, claims:[], reasoningOptions:[], evidenceOptions:[]}`) — locate the factory; if per-type defaults
  exist there, extend; else ensure editor initializes missing arrays.
- `preview/renderers/assessment-renderers.tsx` (or new file): CER_CHOICE
  preview = three labeled sections (Luận điểm / Bằng chứng / Suy luận) showing
  options; register in `preview/activity-renderer.tsx` dispatch.

## Related Code Files
Modify:
- `builder/draft-model.ts`, `builder/labels.ts` (phase-01 territory — same files)
- `builder/activity-editors/index.tsx`
- `builder/activity-editors/evidence-select-editor.tsx`
- `builder/activity-editors/reasoning-connect-editor.tsx`
- `builder/use-builder.ts` (factory defaults — verify)
- `preview/activity-renderer.tsx` + one renderer file
- possibly `builder/stage-editor.tsx` (EditorProps draft threading)
Create:
- `builder/activity-editors/cer-choice-editor.tsx`
- `preview/renderers/cer-choice-preview.tsx` (or extend existing file)
Tests (Vitest):
- `cer-choice-editor.test.tsx`
- extend `builder-page.test.tsx`/`draft-model.test.ts` for the new type

## Implementation Steps
1. Read `shared-fields.tsx` + `use-builder.ts` to confirm EditorProps surface
   and activity factory.
2. Build `cer-choice-editor.tsx` reusing EvidenceRefPicker + FeedbackPanel.
3. Add graded toggles to the two existing editors.
4. Register editor + labels + preview renderer.
5. `npm run test` (vitest) + `npm run build` — gate.

## Todo
- [ ] cer-choice-editor.tsx
- [ ] graded toggle: evidence-select-editor
- [ ] graded toggle: reasoning-connect-editor
- [ ] index.tsx + labels + preview renderer + dispatch
- [ ] factory defaults in use-builder
- [ ] vitest + build green

## Success Criteria
- Author can create a CER_CHOICE activity, fill all keys via UI, save draft,
  and the serialized `draftJson` matches the phase-01 contract exactly
  (round-trip test).
- Graded EVIDENCE_SELECT produces `config.graded:true + acceptedEvidenceIds`.
- Preview renders CER_CHOICE without answer keys visible.
- `vitest run` + `npm run build` clean.

## Risk Assessment
- EditorProps may not expose the whole draft → `priorEvidenceSource` dropdown
  needs stage/activity listing; fallback = plain text input with pattern hint.
- acceptedRelationSets full UI is heavy → MVP exposes expectedRelations only;
  acceptedRelationSets stays a JSON-advanced field (documented).

## Security Considerations
- Answer keys live in draft_json only; admin UI is behind existing admin auth;
  nothing new exposed to learner APIs.
