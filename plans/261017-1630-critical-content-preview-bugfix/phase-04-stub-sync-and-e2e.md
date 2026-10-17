# Phase 04 — Stub sync & e2e spec

## Context Links

- `dau-viet-admin/scripts/e2e-backend-stub.mjs`
- `dau-viet-admin/tests/e2e/publish-journey.spec.ts`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LearnerProjectionService.java` (canonical mirror)
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/SnapshotBuilder.java` (evidence/asset embed logic)

## Overview

- Priority: P1
- Status: pending
- Sync the e2e stub's projection mirror and preview endpoint with the Phase 01/02 backend changes, then rewrite `publish-journey.spec.ts` to cover MC + MATCHING + DRAG_ORDER + evidence preview + republish immutability.

## Key Insights

- Stub `LEARNER_HIDDEN_KEYS` set (line 39) must add `"multiCorrect"`.
- Stub `projectSnapshot()` (line 69) must replicate: MATCHING transform (`pairs` → `leftItems`/`rightItems`), DRAG_ORDER reorder.
- Stub `/preview` endpoint currently does `projectSnapshot(draft)` — must also embed `evidence[]`/`assets[]` like `SnapshotBuilder.build()`.
- Stub `/publish` stores `projectSnapshot(draft)` as `version.snapshot` — the stored snapshot for the learner endpoint should keep the full enriched shape (evidence+assets already embedded) but still be the projected (learner-safe) version since the stub stores projected content directly. NOTE: real backend stores the RAW snapshot (with answer keys) and projects on read. The stub simplifies by storing projected — this is fine for e2e assertions but document the divergence in a comment.
- Evidence/asset embedding in stub: `evidences` and `assets` arrays already exist in-memory; replicate `collectEvidenceIds` logic (walk `stages[].requiredEvidenceIds` + `activities[].evidenceRefs` + `config.visibleEvidenceIds`/`requiredEvidenceIds`/`visibleSourceIds`) and `collectAssetIds` (evidence.assetId + config.imageAssetId).
- Deterministic reorder in stub must match backend algorithm (hash-based or simpler: reverse-then-stable for DRAG_ORDER; left/right index swap for MATCHING — simplest deterministic scheme that differs from authored order).

## Requirements

- Stub `projectSnapshot` mirrors all Phase 01 transforms:
  - `multiCorrect` in `LEARNER_HIDDEN_KEYS`.
  - MATCHING: `config.pairs` → `leftItems`/`rightItems` (deterministic independent order); `pairs` and `correctPairs` absent from learner payload.
  - DRAG_ORDER: `items` reordered deterministically; `expectedOrder` absent.
- Stub `/preview` embeds `evidence[]` + `assets[]` (mirror `SnapshotBuilder` embed logic using in-memory stores).
- Stub `/publish` snapshot stores projected + enriched content (same as before but with evidence/assets).
- E2E spec covers:
  - MC multi-select: editor writes `correctOptionIds`+`multiSelect`; preview shows checkboxes; publish; learner content has no `correctOptionIds`/`multiCorrect`/`correctPairs`.
  - MATCHING: preview shows two columns; learner content has `leftItems`/`rightItems` and no `pairs`/`correctPairs`; assert left/right index pairing is not reconstructible.
  - DRAG_ORDER: learner content `items` order ≠ authored `expectedOrder`.
  - EVIDENCE_SELECT or VERIFICATION preview shows evidence title (not just UUID).
  - Republish: draft edit → publish v2 → v1 snapshot unchanged (check `/versions` list or learner content still serves v1 shape after republish — simplest: assert versionNo=2 and v1 `publishedAt` unchanged via stub store, or assert learner content reflects v2 changes).
  - Preview state reset: author two MC activities, navigate between them in preview, assert no stale selection (if feasible in Playwright; otherwise vitest covers it — mark as optional/stretch).

## Architecture

Stub changes only — no new files.

```
stub.mjs changes:
  LEARNER_HIDDEN_KEYS += "multiCorrect"
  projectSnapshot():
    per-activity transform:
      MATCHING  → leftItems/rightItems, delete pairs
      DRAG_ORDER → deterministic reorder items
  embedEvidence(draft) — walk draft, collect ids, embed from evidences[]
  embedAssets(draft, embeddedEvidence) — collect assetId refs, embed from assets[]
  /preview → projectSnapshot(enrich(draft))
  /publish → projectSnapshot(enrich(draft)) stored as version.snapshot
```

## Related Code Files

Modify:
- `dau-viet-admin/scripts/e2e-backend-stub.mjs`
- `dau-viet-admin/tests/e2e/publish-journey.spec.ts`

Create: none. Delete: none.

## Implementation Steps

1. **Stub — hidden keys**: add `"multiCorrect"` to `LEARNER_HIDDEN_KEYS` set.
2. **Stub — MATCHING transform** in `projectSnapshot`, inside the activity loop before `stripContainer(act)`:
   ```js
   if (act.type === "MATCHING" && act.config?.pairs) {
     const pairs = act.config.pairs;
     const leftItems  = pairs.map(p => ({ id: p.left.id,  label: p.left.label }))
                             .sort((a, b) => a.id.localeCompare(b.id));
     const rightItems = pairs.map(p => ({ id: p.right.id, label: p.right.label }))
                             .sort((a, b) => b.id.localeCompare(a.id)); // reverse — breaks index pairing
     delete act.config.pairs;
     delete act.config.correctPairs;
     act.config.leftItems  = leftItems;
     act.config.rightItems = rightItems;
   }
   ```
   Document: right sorted descending, left ascending — trivially deterministic, index-independent.
3. **Stub — DRAG_ORDER reorder** in same loop:
   ```js
   if (act.type === "DRAG_ORDER" && Array.isArray(act.config?.items) && act.config.items.length >= 2) {
     const items = [...act.config.items];
     // stable deterministic: sort by id desc; if result equals expectedOrder, reverse
     const reordered = items.sort((a,b) => b.id.localeCompare(a.id));
     const ids = reordered.map(i => i.id);
     const expected = act.config.expectedOrder ?? act.config.correctOrder ?? [];
     if (JSON.stringify(ids) === JSON.stringify(expected)) reordered.reverse();
     act.config.items = reordered;
   }
   ```
4. **Stub — evidence/asset embedding**: add `enrichDraft(draft)` helper:
   - Collect evidence ids from `stages[].requiredEvidenceIds`, `activities[].evidenceRefs`, `config.visibleEvidenceIds`, `config.requiredEvidenceIds`, `config.visibleSourceIds`.
   - Look up each in `evidences[]`; emit `{id,title,evidenceType,description,source:{title,author,url,citation},reliability,relevance,assetId}`.
   - Collect asset ids from embedded evidence `assetId` + `config.imageAssetId`; look up in `assets[]`; emit `{id,storageKey,mimeType,sizeBytes,originalFilename,altText}`.
   - Return `{...draft, evidence: [...], assets: [...]}`.
5. **Stub — `/preview`**: change `projectSnapshot(draft)` → `projectSnapshot(enrichDraft(draft))`.
6. **Stub — `/publish`**: change `projectSnapshot(draft)` → `projectSnapshot(enrichDraft(draft))` in the version.snapshot assignment.
7. **E2E spec — `publish-journey.spec.ts`**: extend existing test (or add new `test()`) to author:
   - Stage EVIDENCE → EVIDENCE_SELECT activity with ≥1 `visibleEvidenceIds` (select via UI evidence picker or set via draft manipulation).
   - Stage REASONING → MATCHING activity (author 2+ pairs via editor UI).
   - Stage RECONSTRUCTION → DRAG_ORDER activity (author 3+ steps via editor UI).
   - Stage VERIFICATION → VERIFICATION activity with `visibleSourceIds`.
   - MULTIPLE_CHOICE (multi-select) in any allowed stage.
   - Save → Preview: assert evidence title text visible (not UUID); MATCHING two columns present; MC checkboxes present.
   - Publish → learner content assert: `leftItems`/`rightItems` present; `pairs`/`correctPairs`/`correctOptionIds`/`expectedOrder` absent; `items` order ≠ authored order.
   - Republish v2: edit draft → publish → assert versionNo=2; learner content reflects new draft.
   - Keep existing tests unchanged (event publish blocking, basic publish journey).

   Simplification for UI authoring: if the builder UI for MATCHING/DRAG_ORDER/EVIDENCE_SELECT is too complex for e2e, construct the draft via `PUT /admin/lessons/{id}/draft` directly (stub supports it) — the e2e journey goal is testing the projection contract, not the editor UI. Editor UI tests belong in vitest. Use `page.request.put()` or `fetch` within Playwright to seed the draft, then drive the UI for preview/publish/verify.

## Todo List

- [ ] Stub: `multiCorrect` in hidden keys
- [ ] Stub: MATCHING transform in `projectSnapshot`
- [ ] Stub: DRAG_ORDER deterministic reorder
- [ ] Stub: `enrichDraft` (evidence + assets embed)
- [ ] Stub: `/preview` + `/publish` use `enrichDraft`
- [ ] E2E: MC multi-select checkbox assertion
- [ ] E2E: MATCHING leftItems/rightItems + no pairs leak
- [ ] E2E: DRAG_ORDER items order ≠ expectedOrder
- [ ] E2E: evidence title in preview (not raw UUID)
- [ ] E2E: republish v2 + v1 immutability
- [ ] `npx playwright test --workers=1` green

## Success Criteria

- `npx playwright test --workers=1` — all specs pass including new assertions.
- Stub `/preview` response includes `evidence[]`/`assets[]` when draft references them.
- Learner content has no answer keys; MATCHING columns cannot be paired by index.

## Risk Assessment

- Stub diverges from real backend (stores projected snapshot rather than raw+project-on-read) — already the existing pattern; document in comment.
- If `enrichDraft` is not called on `/publish`, published versions lack evidence — same as before, acceptable for e2e.
- Playwright selectors for MATCHING/DRAG_ORDER editors may be brittle; use draft-seeding via API where UI is too complex.

## Security Considerations

- Stub mirror must never emit hidden keys even in its simplified form — same invariant as backend.

## Next Steps

- Phase 05 runs all gates and produces the Vietnamese report.
