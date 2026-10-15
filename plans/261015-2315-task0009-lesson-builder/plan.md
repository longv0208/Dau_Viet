---
title: "TASK-0009 Lesson Builder Core — Stage, Activity, Evidence & Rules"
description: "Structured draft_json schema + typed validators + admin APIs for stages/activities/evidence + publish-readiness endpoint"
status: pending
priority: P1
effort: 14h
branch: main
tags: [lesson-builder, draft-json, evidence, validation, admin-api]
created: 2026-10-15
---

# TASK-0009 — Lesson Builder Core

Build structured lesson authoring on top of TASK-0008 draft surface. Treat `lessons.draft_json` JSONB as the single source for stages/activities/rules/transitions/evidence-refs. No new tables for stages/activities. Reuse auth, optimistic locking, error envelope from TASK-0007/0008.

## Phase Index

| # | Phase | Status | Effort | File |
|---|---|---|---|---|
| 01 | Draft schema contract | pending | 1h | [phase-01-draft-schema-contract.md](phase-01-draft-schema-contract.md) |
| 02 | DraftValidator redesign | pending | 3h | [phase-02-draft-validator.md](phase-02-draft-validator.md) |
| 03 | Stage + Activity APIs | pending | 4h | [phase-03-stage-activity-apis.md](phase-03-stage-activity-apis.md) |
| 04 | Evidence admin APIs | pending | 3h | [phase-04-evidence-apis.md](phase-04-evidence-apis.md) |
| 05 | Publish-readiness endpoint | pending | 1.5h | [phase-05-publish-readiness.md](phase-05-publish-readiness.md) |
| 06 | Tests | pending | 1.5h | [phase-06-tests.md](phase-06-tests.md) |
| 07 | Docs (API_SPEC + DATABASE_DESIGN) | pending | 0.5h | [phase-07-docs.md](phase-07-docs.md) |

## Key design decisions

| Question | Decision | Rationale |
|---|---|---|
| draft_json shape | `stages[]` ordered array; each stage has `activities[]` ordered array; transitions via `stages[].nextStageIds[]` (multi-target allowed for verify→revise); activities do not carry transitions | Keeps stage graph at one level, matches LEARNING_ENGINE_DESIGN.md `VERIFICATION → HYPOTHESIS` loop; per-activity branching left to `config.onX` if needed later |
| Reorder semantics | Single PATCH per collection with the full ordered `id[]` (`PUT /stages/order`, `PUT /stages/{sid}/activities/order`) | Atomic, idempotent, trivially verifiable; avoids race-prone "move by index" |
| Type-aware validation | `ActivityTypeRegistry` (`Map<ActivityType, ActivityConfigValidator>`) + per-type `ActivityConfigValidator` beans; mirror TASK-0010 `ActivityHandler` registry so names align | Avoids giant switch, makes adding type = adding a bean |
| Evidence ref validation | On save: lenient (warn-level errors if ref missing? — no, simply do not block save); on publish-check: strict, every `config.evidenceIds[]` / `stages[].requiredEvidenceIds[]` must resolve to `evidences.id` with `status IN (DRAFT, APPROVED)` AND `event_id` = lesson.event_id | Drafts are WIP; publish-readiness is the gate. Same validator used both places — only strictness differs |
| New Flyway migration | None for stage/activity (already inside `draft_json`); V6 adds `row_version BIGINT NOT NULL DEFAULT 0` to `evidences` for optimistic lock parity | V3 already has `evidences` + `assets`; no join table needed because evidence refs live inside draft_json as stable string IDs |
| Server-only vs learner-visible | `stages[].activities[].validation`, `feedback.<key>` (key codes only), `config.correctOptionIds`, `config.correctPairs`, `config.expectedOrder`, `config.requiredEvidenceIds` = SERVER_ONLY; rest is learner-visible. Tag via `@JsonView` on read DTO + explicit `LEARNER_HIDDEN_KEYS` Set in `DraftSchema` | Publish (TASK-0010) will strip before snapshot; TASK-0009 marks the boundary so preview (deferred) doesn't leak keys |

## Endpoints (summary — detail in phase files)

```
GET    /api/v1/admin/lessons/{id}/draft/stages
POST   /api/v1/admin/lessons/{id}/draft/stages
PUT    /api/v1/admin/lessons/{id}/draft/stages/order          {orderedIds:[], expectedRowVersion}
GET    /api/v1/admin/lessons/{id}/draft/stages/{stageId}
PATCH  /api/v1/admin/lessons/{id}/draft/stages/{stageId}
DELETE /api/v1/admin/lessons/{id}/draft/stages/{stageId}
GET    /api/v1/admin/lessons/{id}/draft/stages/{stageId}/activities
POST   /api/v1/admin/lessons/{id}/draft/stages/{stageId}/activities
PUT    /api/v1/admin/lessons/{id}/draft/stages/{stageId}/activities/order
GET    /api/v1/admin/lessons/{id}/draft/stages/{stageId}/activities/{activityId}
PATCH  /api/v1/admin/lessons/{id}/draft/stages/{stageId}/activities/{activityId}
DELETE /api/v1/admin/lessons/{id}/draft/stages/{stageId}/activities/{activityId}
POST   /api/v1/admin/lessons/{id}/validate                     -> structured error list

GET    /api/v1/admin/evidences?eventId=&status=&q=
POST   /api/v1/admin/evidences
GET    /api/v1/admin/evidences/{id}
PATCH  /api/v1/admin/evidences/{id}
POST   /api/v1/admin/evidences/{id}/archive                    (refused if referenced by published snapshot)
```

All mutating endpoints accept `expectedRowVersion`. All return standard error envelope.

## Dependencies

- TASK-0008 (done): lessons CRUD, optimistic lock, error envelope, `DraftValidator` placeholder, admin auth
- TASK-0007 (done): JWT + CONTENT_ADMIN
- V3 migration: `evidences`, `assets`, `lessons`, `lesson_versions` schema in place
- V6 (new): `evidences.row_version` — required for optimistic-lock parity

## Risk

`high-risk` — new API surface, structured-validation rules drive publish gate in TASK-0010, evidence lifecycle policy affects data retention.

## Unresolved questions

1. Should `stage.transitions` allow activity-level transitions (e.g., `activity.onPartial -> stageId`), or stage-level only? Currently stage-level `nextStageIds[]`; activity-level escape hatches (verify → revise hypothesis) modeled as stage-to-stage. Confirm with LEARNING_ENGINE_DESIGN §7 single-loop rule.
2. Evidence `status` semantics for learner visibility: do we require evidence `APPROVED` to publish, or allow `DRAFT`? Plan allows DRAFT+APPROVED; tighten if PO wants.
3. `assets` endpoints — not in scope for TASK-0009 but evidence may reference `asset_id`. Treat `asset_id` as free UUID, existence validated only at publish-check (asset must exist and `state=ACTIVE`)? Currently yes.
4. `id` format for stages/activities: slug (`stage-context`, `act-intro`) or UUID? Plan uses free-form string IDs with regex `[a-z0-9][a-z0-9-]{1,63}` so templates can preset stable semantic IDs.
5. Should `orderedIds[]` PATCH also accept deletes (id in draft but not in orderedIds -> remove) or must client explicitly DELETE first? Plan: explicit DELETE required; PUT order fails if any draft id missing from array (forces intent).
