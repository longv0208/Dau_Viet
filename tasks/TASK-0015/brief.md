# TASK-0015 — Dấu Việt Admin Web: Stage & Activity Builder

Visual Stage & Activity Builder inside the Next.js Admin app. A non-technical
Content Admin must create real interactive stages/activities without writing
JSON, save the structure as a valid backend draft, and reopen without loss.

Full brief is in the task request. Key points:

- Route `/lessons/[id]/builder`, 3-pane workspace (stage navigator / editor / inspector), responsive collapse.
- Stage ops: add/rename/retype/reorder/delete/duplicate, required flag, nextStageIds via selectors (no manual UUID).
- Activity ops: add/edit/reorder/remove, ActivityType picker (Vietnamese names + explanation + icon), typed forms for at least READ, VIEW_IMAGE, MULTIPLE_CHOICE, EVIDENCE_SELECT, MATCHING, DRAG_ORDER, CER; unsupported types get an honest placeholder, never silently-invalid saves.
- draftJson ownership: load GET /admin/lessons/{id}, parse to typed models, save via PUT /admin/lessons/{id}/draft with expectedRowVersion, preserve unknown fields, show SAVE-level validation errors, never corrupt published snapshots.
- Template behavior: inspect what backend instantiates; if empty, offer explicit "Tạo cấu trúc từ khung bài học" — never silently replace work.
- Validation: field/stage/activity indicators, error list, save feedback, unsaved-changes guard, delete confirmation; SAVE vs PUBLISH validation kept distinct — partial drafts saveable.
- Semantics: optional stages must not block completion; required activities consistent with parent; transitions reference valid stage IDs; stable unique activity IDs; no unsupported types emitted.
- Representative Bạch Đằng example (CONTEXT/EVIDENCE/RECONSTRUCTION/CONCLUSION) — no event-specific logic in reusable components.
- Tests: builder flows (add/edit/reorder/delete stage+activity, MC + DRAG_ORDER config, partial save, reload persistence, errors, published immutability) + Playwright vs controlled stub; real-backend smoke only if env permits — never misrepresent stub as real.
- Out of scope: asset upload, evidence library, publish workflow, mobile preview, Flutter, users, analytics, rewards.
- Gates: lint, tsc, vitest, next build, playwright. Final report in Vietnamese. No push/merge without permission.
