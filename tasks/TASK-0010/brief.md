# TASK-0010 — Lesson Publishing, Versioning & Learner-Safe Content API

Implement the publish workflow on top of the TASK-0009 lesson builder. A publish takes the current `lessons.draft_json`, runs PUBLISH-level `DraftValidator`, verifies the event/template are eligible, writes an immutable `lesson_versions` snapshot (version_no = max+1 per lesson), and atomically sets `lessons.current_version_id` + status `PUBLISHED` + `published_at`/`published_by` — all in one transaction, safe under concurrent publish.

Deliverables: `POST /api/v1/admin/lessons/{id}/publish`; admin version list/get/current APIs; a learner-safe projection that strips `DraftSchema.LEARNER_HIDDEN_KEYS` and validation internals; public learner read APIs for published lessons + their current snapshot content; `POST /api/v1/admin/lessons/{id}/preview` returning the same projection over the draft without publishing. Snapshot JSONB is the single published source of truth — embed the learner-facing fields a renderer needs; answer keys and hidden rubric never leave the admin/validation surface.

Out of scope: admin UI, Flutter renderer, learning-engine runtime, attempts/submissions/scoring/rewards, asset upload flows, new Flyway migrations (existing `lesson_versions` table + immutable trigger are reused).
