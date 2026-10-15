# TASK-0009 — Lesson Builder Core: Stage, Activity, Evidence & Rules

Implement the structured lesson-draft authoring surface on top of the TASK-0008 lesson skeleton. `lessons.draft_json` is the single source of truth for stages/activities/rules/transitions/evidence references — no new domain tables for these subentities (per `docs/DATABASE_DESIGN.md` §2).

Deliverables: a canonical `draft_json` schema (v1) with server-only vs learner-visible field separation; a redesigned `DraftValidator` producing field-level errors at two levels (SAVE lenient, PUBLISH strict) with a per-`ActivityType` validator registry; sub-resource admin endpoints under `/api/v1/admin/lessons/{id}/draft/stages` and `/stages/{sid}/activities` for CRUD + atomic reorder; an `Evidence` admin CRUD at `/api/v1/admin/evidences` (V6 adds `row_version`); and a publish-readiness endpoint `POST /api/v1/admin/lessons/{id}/validate` returning `{ready, errors[], warnings[]}` without creating `lesson_versions` (deferred to TASK-0010).

All endpoints require `CONTENT_ADMIN` (existing `/api/v1/admin/**` SecurityConfig), honour `expectedRowVersion` optimistic locking, reuse the `{code,message,details,traceId}` error envelope, and run inside `saveAndFlush` transactions. The `evidences` lifecycle is `DRAFT→APPROVED→ARCHIVED` with no destructive delete; archive is refused when an in-flight published `lesson_versions.snapshot_json` references the evidence id.

Out of scope: admin UI, Flutter renderer, actual `lesson_versions` snapshot creation (TASK-0010), learning-engine runtime, submissions/scoring/rewards, object-storage upload flows.
