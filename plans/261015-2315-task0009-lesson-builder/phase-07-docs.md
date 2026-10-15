# Phase 07 — Documentation updates

## Context links
- `docs/API_SPEC.md` §3 — admin endpoints; §4 — error model
- `docs/DATABASE_DESIGN.md` §3 — evidences row; §4 — draft snapshot contract
- `docs/backend-flutter-contract-notes.md` (if exists — check)

## Overview
- Priority: P2
- Status: pending
- Document the new endpoints, schema contract, and evidence lifecycle. Keep diffs surgical — do not rewrite existing sections.

## Requirements

### `docs/API_SPEC.md`

In §3 admin endpoints table, replace the `POST /admin/lessons/{lessonId}/validate` placeholder row (currently marked `TASK-0009`) and add:

```
| GET    | /admin/lessons/{id}/draft/stages | List draft stages |
| POST   | /admin/lessons/{id}/draft/stages | Add stage |
| GET    | /admin/lessons/{id}/draft/stages/{stageId} | Stage detail |
| PATCH  | /admin/lessons/{id}/draft/stages/{stageId} | Update stage |
| DELETE | /admin/lessons/{id}/draft/stages/{stageId} | Remove stage |
| PUT    | /admin/lessons/{id}/draft/stages/order | Reorder stages |
| GET    | /admin/lessons/{id}/draft/stages/{sid}/activities | List activities |
| POST   | /admin/lessons/{id}/draft/stages/{sid}/activities | Add activity |
| GET    | /admin/lessons/{id}/draft/stages/{sid}/activities/{aid} | Detail |
| PATCH  | /admin/lessons/{id}/draft/stages/{sid}/activities/{aid} | Update |
| DELETE | /admin/lessons/{id}/draft/stages/{sid}/activities/{aid} | Remove |
| PUT    | /admin/lessons/{id}/draft/stages/{sid}/activities/order | Reorder activities |
| POST   | /admin/lessons/{id}/validate | Publish-readiness check (implemented TASK-0009) |
| GET    | /admin/evidences | List (eventId,status,q,pagination) |
| POST   | /admin/evidences | Create |
| GET    | /admin/evidences/{id} | Detail |
| PATCH  | /admin/evidences/{id} | Update |
| POST   | /admin/evidences/{id}/approve | DRAFT→APPROVED |
| POST   | /admin/evidences/{id}/archive | →ARCHIVED (409 if referenced by published) |
```

Add a new subsection `### Notes đã chốt TASK-0009` covering:
- Sub-resource mutations rewrite `draft_json` and use `expectedRowVersion` (same optimistic-lock contract).
- Reorder via `PUT .../order` with full `orderedIds[]`; mismatched set → 400.
- Stage deletion cascades: prunes `nextStageIds` references and `completion.requiredStageIds`.
- `/validate` returns 200 always (errors in body, not HTTP error); does not create `lesson_versions`.
- New error codes: `STAGE_NOT_FOUND`, `ACTIVITY_NOT_FOUND`, `STAGE_ACTIVITY_MISMATCH`, `CIRCULAR_TRANSITION`, `UNSUPPORTED_ACTIVITY_TYPE`, `EVIDENCE_NOT_FOUND`, `EVIDENCE_IN_USE`, `ASSET_NOT_FOUND`, `TEMPLATE_SCHEMA_MISMATCH`.
- `validation` and `config.correct*` are server-only fields — never sent to learner.

In error code table: append new codes.

### `docs/DATABASE_DESIGN.md`

- §3 evidences row: append `row_version` (V6).
- §4 contract: replace illustrative example with the canonical v1 shape from `phase-01-draft-schema-contract.md` (keep concise — link to phase file or inline a compact JSON).
- Add migration list line: `V6` adds `evidences.row_version`.

### `docs/backend-flutter-contract-notes.md`

If exists: append a one-paragraph note that admin endpoints under `/api/v1/admin/lessons/{id}/draft/*` are admin-only and not part of Flutter contract. If absent, skip.

### `docs/PROGRESS.md`

Do not edit by hand — generated. Harness/task updates will refresh it.

## Files

Modify:
- `docs/API_SPEC.md` — admin endpoint table + error codes + new notes subsection
- `docs/DATABASE_DESIGN.md` — evidences row_version, draft contract refresh, migration list

## Implementation steps
1. API_SPEC: edit §3 table (insert rows under existing lessons block).
2. API_SPEC: add `Notes đã chốt TASK-0009` section.
3. API_SPEC: append error codes.
4. DATABASE_DESIGN: update evidences row + migration list + draft contract.
5. Spot-check link integrity (no broken anchors).

## Todo
- [ ] API_SPEC endpoint table updated
- [ ] API_SPEC new notes section
- [ ] API_SPEC error codes added
- [ ] DATABASE_DESIGN V6 + schema contract
- [ ] Verify no stale "TASK-0009" placeholders remain

## Success criteria
- `/validate` documented with response shape.
- All new error codes listed.
- `draft_json` canonical shape documented (or linked to phase-01).
- No contradictory info between API_SPEC and DATABASE_DESIGN.

## Risks
- Low — additive doc changes only.
