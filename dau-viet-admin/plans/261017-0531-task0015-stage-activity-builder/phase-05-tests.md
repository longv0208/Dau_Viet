# Phase 05 — Tests + docs + final gates

## Context links

- Existing test patterns: `src/test/msw/handlers.ts`, `src/test/fixtures.ts`, `src/features/lessons/lesson-basic-form.test.tsx`, `tests/e2e/authoring.spec.ts`, `scripts/e2e-backend-stub.mjs`.
- Backend test fixture: `dau-viet-backend/src/test/java/com/dauviet/learning/AttemptItFixture.java` (canonical draft JSON samples).

## Overview

- Priority: P1
- Status: pending
- Effort: 3h
- Goal: cover the builder flows in vitest (unit + component) and Playwright (e2e with stub); update runbook; keep all gates green (`lint`, `tsc`, `vitest`, `next build`, `playwright`).

## Key insights

- MSW intercepts `/api/proxy/*` (client side) — extend `handlers.ts` for `PUT /api/proxy/admin/lessons/:id/draft` + `POST /api/proxy/admin/lessons/:id/validate`.
- Playwright stub is `node:http` — extend with same endpoints; the stub's in-memory `lessons[]` must hold `draftJson` between save and reload.
- Test fixture drafts should reuse the canonical shape from `AttemptItFixture.draftTwoStage` (CONTEXT → EVIDENCE) to keep authoring/test realism.

## Requirements

### Vitest coverage

- `draft-model.test.ts` — round-trip, unknown keys, malformed input, id gen.
- `draft-schemas.test.ts` — per-type validation cases (≥1 positive + ≥2 negatives per type: missing required field, allow-map violation, id-pattern).
- `use-builder.test.ts` — reducer invariants: delete stage prunes nextStageIds + completion; duplicate stage generates unique ids; mergeStages remaps template ids.
- `stage-navigator.test.tsx` — add stage flow (open picker → pick type → appears in list); reorder; delete confirm.
- `multiple-choice-editor.test.tsx` — single vs multi mode switching emits correct field; ≥2 options enforced; correctOptionIds ⊆ option ids.
- `drag-order-editor.test.tsx` — items order drives `expectedOrder`; remove item prunes it.
- `builder-page.test.tsx` — full integration: load fixture draft → edit MC option → save → assert PUT body contains expected `draftJson` (parse and compare); save 422 → error list rendered; 409 → reload prompt.
- `template-seed-button.test.tsx` — presetJson `"{}"` → disabled; non-empty stages → confirm → stages merged.

### Playwright (`tests/e2e/builder.spec.ts`)

- Authoring flow: login → create lesson (or reuse) → open builder → add stage CONTEXT → add READ activity → save → reload → state preserved.
- Partial save: build CONTEXT stage with empty config activity → save → no 422.
- Validation error surfacing: force a save-time violation (e.g., delete all stages then try to add invalid config) → assert error panel shows mapped message.
- Published lesson immutability: pre-seed lesson with `status:"PUBLISHED"` (stub) → open builder → banner shown; save still writes to draft_json not snapshot (assert via stub's `currentVersionId` unchanged).

### Stub extensions (`scripts/e2e-backend-stub.mjs`)

- `PUT /api/v1/admin/lessons/:id/draft` — read `draftJson` + `expectedRowVersion`; 409 on version mismatch; validate minimal (must be object); bump `rowVersion`.
- `POST /api/v1/admin/lessons/:id/validate` — return `PublishReadinessResponse` with canned `{ready, errors, warnings, summary}` — deterministic per lesson state.
- Keep stub honest — comment clearly "controlled stub, not real backend".

### MSW additions

- Mirror stub endpoints in `src/test/msw/handlers.ts` for component tests.

### Docs

- `docs/admin-runbook.md` — add "Stage & Activity Builder" section: route, save semantics, validation levels, known limitations (no evidence/asset pickers, no onPartial/onContradicted emission).

## Architecture

Vitest (jsdom) for unit+component; Playwright (real browser + node stub) for end-to-end authoring flow.

## Related code files

**Create:**
- `src/features/lessons/builder/*.test.ts(x)` per file listed above
- `tests/e2e/builder.spec.ts`

**Modify:**
- `src/test/msw/handlers.ts` — add PUT draft + POST validate handlers
- `scripts/e2e-backend-stub.mjs` — add PUT draft + POST validate endpoints
- `src/test/fixtures.ts` — add `draftFixture`, `lessonDetailWithDraftFixture`
- `docs/admin-runbook.md` — builder section

## Implementation steps

1. Extend `handlers.ts` + `e2e-backend-stub.mjs` with new endpoints.
2. Add fixtures.
3. Write unit tests bottom-up: `draft-id` → `draft-model` → `draft-schemas` → `use-builder`.
4. Write component tests for each typed editor + navigator.
5. Write `builder-page.test.tsx` integration test.
6. Write `tests/e2e/builder.spec.ts` for the four scenarios.
7. Update `docs/admin-runbook.md`.
8. Run all gates; fix issues.

## Todo list

- [ ] MSW handlers extended
- [ ] E2E stub extended (PUT draft + POST validate)
- [ ] Fixtures
- [ ] Unit tests: draft-id, draft-model, draft-schemas, use-builder
- [ ] Component tests: navigator, picker, MC editor, drag-order editor, cer editor, unsupported fallback
- [ ] Integration: builder-page save flow
- [ ] Playwright: builder spec
- [ ] `docs/admin-runbook.md` update
- [ ] `pnpm lint` clean
- [ ] `pnpm tsc --noEmit` clean
- [ ] `pnpm vitest run` green
- [ ] `pnpm next build` green
- [ ] `pnpm playwright test` green

## Success criteria

- All gates pass on `main` after merge.
- Test suite covers add/edit/reorder/delete for stages AND activities, MC + DRAG_ORDER config round-trip, partial save, reload persistence, validation errors, published immutability.
- Stub clearly labeled "controlled stub — not real backend" in source comments and plan docs.

## Risk assessment

- Component tests of nested RHF forms — use `data-testid` on buttons + `aria-label` on Vietnamese labels; don't rely on text matching alone for Vietnamese.
- Playwright timing: stub latency is zero — keep `expect(...).toHaveURL` timeouts generous.
- Vitest + Tailwind class assertions — don't assert on classes; assert on accessible roles/names.

## Security considerations

- No new secrets; tests use fixture admin user only.
- Don't snapshot-test full `draftJson` — assert on specific keys to avoid brittle fixtures.

## Next steps

- Hand off to `code-reviewer` for final pass + `docs-manager` for changelog/roadmap entries.
