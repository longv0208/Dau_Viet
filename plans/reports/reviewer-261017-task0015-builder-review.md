# TASK-0015 — Stage & Activity Builder: Code Review

Reviewer: code-reviewer | Date: 2026-10-17 | Scope: `dau-viet-admin/src/features/lessons/builder/**`, route, tests, stub, runbook. Verified against `plans/261017-0531-task0015-stage-activity-builder/` (5 phases) and the backend contract report `plans/reports/planner-261017-0531-task0015-draft-contract.md`.

## Verdict

Overall PASS with minor issues. The implementation is contract-faithful: whole-document PUT, `expectedRowVersion`, slug ids, `STAGE_ALLOWED_ACTIVITIES` verbatim, spread-through codec, MC mutual-exclusivity, honest unsupported fallback, PUBLISHED banner, ARCHIVED read-only, 409-reload flow, template seeding with confirm + full id remap. Vietnamese copy is natural; no emojis; no secrets; no `dangerouslySetInnerHTML`.

## Acceptance-criteria verdicts (brief.md)

| AC | Verdict | Evidence |
|---|---|---|
| Route + 3-pane workspace | PASS | `src/app/(admin)/lessons/[id]/builder/page.tsx`, `builder-page.tsx` grid `lg:grid-cols-[260px_1fr_300px]` |
| Stage ops add/rename/retype/reorder/delete/duplicate, required, nextStageIds | PASS | navigator (add/reorder/duplicate/delete), stage-editor (title rename, type retype, required, nextStageIds chips) |
| Activity ops + picker filtered by stage type | PASS | `activity-picker.tsx` uses `STAGE_ALLOWED_ACTIVITIES[stageType]` |
| Typed editors ≥7 + honest fallback | PASS | 8 typed editors (incl. REFLECTION_PROMPT bonus); UnsupportedEditor read-only raw view for 4 remaining |
| draftJson ownership (parse→typed→PUT w/ expectedRowVersion, preserve unknown) | PASS w/ P2 | codec spreads all levels; nested item objects (options/pairs/items) rebuilt to `{id,label}` on edit — see I-2 |
| Template seeding: explicit, never silent, remaps ids + nextStageIds | PASS | `template-seed-button.tsx` two-pass remap + `window.confirm`, append-only |
| Validation: field indicators + error list + save feedback + unsaved guard + delete confirm | PASS w/ P1 | inline `role=alert` hints + server-error panel click-to-jump + guard + inline Xoá/Giữ. Client-side zod schemas planned but NOT implemented — see I-1 |
| SAVE vs PUBLISH distinct; partial drafts saveable | PASS | no client blocking; publish readiness via `POST /validate` never gates save |
| Semantics (optional stage, required-consistency warning, unique ids, no unsupported emitted) | PASS w/ P2 | warning banner on required-in-optional; id generator collision gap in `duplicateStage` — see I-3 |
| Bạch Đằng representative example, no event-specific logic | PASS | fixtures use Bạch Đằng draft; components are generic |
| Tests: unit + e2e vs stub | PASS w/ P2 | 56 vitest, 3 builder e2e cases. Missing: 409 conflict, PUBLISHED-status e2e, mergeStages unit — see I-4 |
| Gates | PASS (reported green) | tsc, lint, vitest 56/56, build, playwright 8/8 |

## Contract-requirement verdicts (12 items)

1. draftJson round-trip preserves unknown fields — PASS at object level (top/stage/activity/config all spread); PARTIAL at nested item level (I-2).
2. PUT `{draftJson, expectedRowVersion}` whole-document — PASS (`builder-page.tsx:130-138`).
3. Slug ids `^[a-z0-9][a-z0-9-]{1,63}$` — PASS (`draft-id.ts`, verified in tests).
4. Picker filters `STAGE_ALLOWED_ACTIVITIES` exactly — PASS (`draft-model.ts:39-49` mirrors Java verbatim).
5. MC emits exactly one of correctOptionIds|multiCorrect — PASS (`multiple-choice-editor.tsx:56-59` deletes both then writes one; test asserts).
6. SAVE vs PUBLISH distinct — PASS.
7. Template presetJson seeding: confirm + remap all ids + internal nextStageIds — PASS (`template-seed-button.tsx:57-78`).
8. Server-only keys not shown as learner-facing — PASS (labels say "không hiển thị cho học viên"; rendered only in authoring inputs).
9. 409 prompts reload, never silent-retry — PASS (`builder-page.tsx:204-211`, seedKey remount).
10. Unknown activity types honest fallback — PASS (`unsupported-editor.tsx` read-only raw + codec preserves).
11. Unsaved-changes guard while dirty — PASS (`builder-page.tsx:128`).
12. No emojis — PASS (only typographic arrows `↔` in matching UI, acceptable).

## Issues

### P1

- **I-1 — Planned zod client-side validation (`draft-schemas.ts`) not implemented.** Phase-01 required zod schemas per activity type + `draft-schemas.test.ts` (≥1 positive + ≥2 negative per type). File absent; validation is inline-hint-only (`role=alert` texts) + server-side on save. Consequence: authors only learn about schema violations after a failed save round-trip; unit tests for per-type config shapes don't exist. Arguably consistent with AC "partial drafts must be saveable" but it IS a plan deliverable skipped silently — either implement the schemas (recommended for publish-readiness parity) or record the deviation in the plan/runbook. Files: plan `phase-01-draft-model.md` steps 3, 63, 82-83; missing `src/features/lessons/builder/draft-schemas.ts`.

### P2

- **I-2 — Nested item objects lose unknown keys on edit.** `readOptions`/`readPairs`/`readItems` map raw items to `{id,label}` and `write()` rebuilds `options`/`pairs`/`items` arrays with only `{id,label}` — extra keys inside items (e.g. `image`, `hint`, `text`) are dropped the first time the user touches that editor, while the codec's contract is "never silently drop". Fix: keep the raw object and spread it on write — `next.map((o,i) => ({...rawOptions[i], id:o.id, label:o.label}))` or store item extras alongside. Files: `activity-editors/multiple-choice-editor.tsx:54`, `matching-editor.tsx:44-49`, `drag-order-editor.tsx:40-42`.

- **I-3 — `duplicateStage` can mint duplicate activity ids.** Each copy activity id is generated against `ids + act.id` — previously generated copy ids aren't added to the exclusion set, so two activities in the same duplicated stage could collide (~1/36^6 per pair — remote but unguarded). Also `mergeStages` template remap doesn't dedupe `requiredEvidenceIds`/`evidenceRefs` (harmless — they're not ids in the draft namespace). Fix: accumulate `taken.push(newId)` inside the activities map like `template-seed-button.tsx` does. File: `use-builder.ts:119-122`.

- **I-4 — Test coverage gaps vs plan.** (a) No 409 test anywhere — MSW `PUT` handler (`handlers.ts:163`) even computes `rowVersion = expectedRowVersion+1` so it can never produce a conflict; component-level conflict banner is untested. (b) No PUBLISHED-status e2e/component test (plan phase-05 required "published immutability" scenario; stub can't even seed PUBLISHED lessons — `e2e-backend-stub.mjs:244` hardcodes `status:"DRAFT"`). (c) No `mergeStages`/template-remap unit test in `use-builder.test.ts` (e2e covers it indirectly). Files: `src/test/msw/handlers.ts:146-169`, `tests/e2e/builder.spec.ts`, `use-builder.test.ts`.

- **I-5 — `setParseError` called inside `useMemo`.** Side-effect during render; React tolerates same-component setState-in-render but inside useMemo is fragile (double-invocation in StrictMode calls it twice — harmless here, still an anti-pattern). Move to `useEffect` keyed on `lesson`, or compute parse in event handler. File: `builder-page.tsx:59-67`.

- **I-6 — File-size guideline exceeded (200 LOC).** `stage-editor.tsx` 275, `builder-page.tsx` 264, `use-builder.ts` 245. Non-blocking per instructions; candidates for split: activity list → `activity-list.tsx`, save-bar/status chips → `save-bar.tsx`, stage metadata → `stage-meta-form.tsx`.

- **I-7 — Minor input bugs.** (a) `minRequired`/`minScore` inputs accept non-numeric text → `Number("abc")=NaN` → serializes as `null` → emits `minRequired:null` / `minScore:null` (type error only at SAVE; still sloppy). Files: `evidence-select-editor.tsx:63`, `completion-editor.tsx:89`. (b) CER `key={i}` on criteria rows — fine today (no reorder), fragile if reorder added. File: `cer-editor.tsx:45`. (c) `aria-label`/`Label` elements without `htmlFor` on grouped controls ("Đáp án", "Các giai đoạn bắt buộc…", "Bắt buộc hoàn thành") — use `<fieldset>`/`<legend>` or `role="group"` + `aria-labelledby` instead of orphan `<label>`. Files: `stage-editor.tsx:78,100`, `multiple-choice-editor.tsx:109`, `completion-editor.tsx:50`.

- **I-8 — MSW stub diverges from real backend on conflict.** Beyond I-4a, `handlers.ts` PUT also never validates MC config (e2e stub does). Component tests can pass against a stub that's laxer than the real SAVE validator — fine as a default, but the 422-path test relies on a `server.use` override anyway. Note only.

### P3 (nits)

- `lesson-basic-form.tsx:275-281` — `CardDescription` and the paragraph repeat the same sentence.
- `matching-editor.tsx:108-109` — new pair's `right` id isn't guaranteed ≠ `left` id (same negligible collision class as I-3).
- Typographic `↔`/`→` in UI/comments — not emojis, acceptable, listed for completeness.
- `Label` `htmlFor` on `min-score` uses a global id `min-score`; duplicate ids if the component ever renders twice on one page — unlikely, fine.

## Recommendations

1. Decide on `draft-schemas.ts`: implement it (keeps SAVE-level parity testable and enables offline "check before save"), or update `phase-01`/runbook documenting the deliberate skip (relying on server 422s). Do not leave it silent.
2. Fix I-2 by spreading raw item objects on write — 5-line change per editor; preserves the codec promise end-to-end.
3. Fix I-3 by threading a growing `taken` array through the duplicate map (mirror `template-seed-button.tsx` pass-1 pattern).
4. Add three cheap tests: (a) `server.use` 409 → conflict banner + reload button remounts with fresh draft; (b) fixture override `status:"PUBLISHED"` → banner rendered + save still issues PUT; (c) `mergeStages` unit test asserting remapped ids.
5. Extract `activity-list.tsx` + `save-bar.tsx` from `stage-editor.tsx`/`builder-page.tsx` when next touching those files — brings all files under the 200-line guideline.
6. Optional hardening: `inputMode="numeric"` + regex-gate numeric fields; convert orphan `<Label>` group captions to `<fieldset><legend>`.

## Resolved contract items worth noting

- `onPartial`/`onContradicted` correctly NOT emitted anywhere (backend `ACTIVITY_KEYS` would reject) — VERIFICATION falls to UnsupportedEditor, consistent with plan.
- Codec test proves `unknownStageKey`, `weird`, `futureCfg`, top-level `futureField` round-trip intact.
- Stub is honest: comment + runbook clearly label it "controlled stub, not real backend"; real-backend smoke honestly flagged as not run.

## Open questions

- Was skipping `draft-schemas.ts` a deliberate scope call (server-as-validator) or an omission? Needs owner decision; recommendation stands either way.
- Backend still lacks an evidence/asset catalogue endpoint — free-text UUID inputs remain the documented TASK-0016 dependency; no action here.
