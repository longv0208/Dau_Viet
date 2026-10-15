---
title: "TASK-0010 Lesson Publishing, Versioning & Learner-Safe Content API"
description: "Transactional publish to lesson_versions + snapshot build + learner-safe projection + preview + version read APIs"
status: pending
priority: P1
effort: 9h
branch: main
tags: [publish, lesson-versions, snapshot, learner-api, admin-api]
created: 2026-10-16
---

# TASK-0010 — Lesson Publishing, Versioning & Learner-Safe Content API

## Context Links

- `docs/API_SPEC.md` §2 learner endpoints, §3 publish/preview rows + request/response shape, §4 authz/idempotency notes
- `docs/DATABASE_DESIGN.md` — `lesson_versions` immutable trigger, `chk_lesson_published_version`, `draft_json` v1 contract
- `docs/LEARNING_ENGINE_DESIGN.md` §6 — stage→activity allow-map
- Code: `lesson/application/LessonService.java` (`checkPublishReadiness`, publish stub at `LessonService#publish`), `LessonDraftService`, `lesson/draft/DraftValidator.java` (PUBLISH level), `DraftSchema.java` (`LEARNER_HIDDEN_KEYS`), `lesson/api/AdminLessonController.java` (publish stub 409), `V3__authoring_publishing_evidence_assets.sql`, `common/error/{ErrorCode,GlobalExceptionHandler}.java`
- TASK-0009 plan (`plans/261015-2315-task0009-lesson-builder/`) for conventions

## Overview

Ship real publish: validate draft at PUBLISH level → build immutable `lesson_versions.snapshot_json` → atomically update `lessons.{status,current_version_id,updated_by}` in one transaction. Expose admin version-list/get + learner-safe preview + public learner lesson APIs (metadata + snapshot). Reuse TASK-0009 validator + readiness logic; add a single projection component that strips server-only keys for learner payloads.

## Key Insights / Decisions

| Question | Decision | Rationale |
|---|---|---|
| Concurrency for `version_no` | **Pessimistic lock** on `lessons` row (`SELECT ... FOR UPDATE` via `@Lock(PESSIMISTIC_WRITE)` on a `findForUpdate` repository method) then `version_no = max+1` | Simplest correct: lesson row is the natural serialization point; unique `(lesson_id,version_no)` is still a backstop. Avoids retry-loop complexity. |
| Snapshot content strategy | **Embed denormalized learner-facing fields** for evidence (id, title, evidenceType, description, source{title,author,url,citation,publishedAt}, reliability, relevance) and asset metadata (id, storageKey, mimeType, altText, sizeBytes). Keep server-only `validation` internals + `LEARNER_HIDDEN_KEYS` in snapshot (needed by server-side evaluation later), but strip them at learner projection | `snapshot_json` is THE published truth — admin edits must not retroactively change a published version. Embedding evidence data (not just IDs) is required because TASK-0009 already implemented `EVIDENCE_IN_USE` guard via `LIKE` scan on snapshot_json — embedded ids keep that guard working. Server-only keys stay in snapshot so future submit-eval can use them; learner projection strips them at read time. |
| Preview | Reuses same projection service on `draft_json`, no publish | Zero duplication; preview is "what learner would see if published now". |
| Publish on PUBLISHED lesson | Allowed (creates `version_no = max+1`) | Spec note §3 says republish allowed; `current_version_id` rotates; attempts stay pinned to old version. |
| Publish on ARCHIVED lesson | 409 `INVALID_STATUS_TRANSITION` | Same rule as edit/archive. |
| Event must be PUBLISHED to publish lesson? | **Warn, do not block** | Spec is silent; blocking adds coupling. Surface as a warning inside publish flow's readiness check but still allow publish so admin can stage lessons ahead of event publish. Flag as open question. |
| Idempotency-Key on publish | Accept header, **do not implement** `idempotency_records` wiring this task | V4 table exists but no service layer yet. Full idempotent-publish is a separate concern (requires request hash + response replay). Note in plan + open question; surface `Idempotency-Key` in spec but treat as deferred. |
| Learner attempt-pinning enforcement | **Deferred to learning-engine task** | Attempts table exists (V4) but no `POST /attempts` flow yet, so "authorize specific-version fetch by attempt ownership" has nothing to check against. Learner API returns the *current* published version only; `GET /versions/{versionId}` content stays admin-only until attempt flow lands. |
| ErrorCode additions | `LESSON_NOT_PUBLISHED`, `VERSION_NOT_FOUND` | Both map to 404 envelope. Reuse `INVALID_STATUS_TRANSITION` for ARCHIVED publish, `DRAFT_SCHEMA_INVALID` envelope for 422 publish-validation failures (same shape as validate endpoint). |

## Requirements

- `POST /api/v1/admin/lessons/{id}/publish` — CONTENT_ADMIN; body `{expectedRowVersion?}`. 200 → `{lessonId, lessonVersionId, versionNo, status:"PUBLISHED"}`. 404 `LESSON_NOT_FOUND`, 409 `INVALID_STATUS_TRANSITION` (ARCHIVED), 409 `OPTIMISTIC_LOCK_CONFLICT`, 422 `DRAFT_SCHEMA_INVALID` with `details.errors[]` (same shape as `/validate` errors).
- `POST /api/v1/admin/lessons/{id}/preview` — CONTENT_ADMIN; 200 learner-safe projection built from current `draft_json` (no write, no publish). Response mirrors what `GET /api/v1/lessons/{id}/content` would emit if published.
- `GET /api/v1/admin/lessons/{id}/versions` — CONTENT_ADMIN; paged list `{items:[{id,versionNo,schemaVersion,publishedAt,publishedBy}],page,size,total}` ordered `versionNo desc`.
- `GET /api/v1/admin/lessons/{id}/versions/{versionId}` — CONTENT_ADMIN; full snapshot including server-only keys (admin sees all).
- `GET /api/v1/admin/lessons/{id}/versions/current` — convenience alias resolving `lessons.current_version_id`.
- `GET /api/v1/lessons/{id}` — public (permit-all like events); returns metadata `{id,title,centralQuestion,eventId,status,publishedAt,currentVersionId}`; only `PUBLISHED` lessons (404 `LESSON_NOT_FOUND`/`LESSON_NOT_PUBLISHED` otherwise).
- `GET /api/v1/lessons/{id}/content` — public; learner-safe projection of current published `snapshot_json` with `LEARNER_HIDDEN_KEYS` stripped recursively inside `config`/`validation`, and `validation` fields normalized to non-answer shapes.
- `GET /api/v1/events/{eventId}/lessons` — public; lists published lessons for a published event (404 event not published).

## Architecture

- **New components**
  - `lesson/draft/SnapshotBuilder.java` — takes `Lesson` + parsed draft `ObjectNode` → builds `snapshot_json` payload: `{schemaVersion, lessonId, title, centralQuestion, objectives[], templateCode, stages[] (as-authored), completion, evidence[] (denormalized), assetMeta[] (denormalized)}`. Loads `Evidence` rows for referenced ids + `Asset` rows via `assetId` on evidence and asset refs inside `config`. Leaves server-only keys untouched (server-side needs them later).
  - `lesson/application/LearnerProjectionService.java` — `toLearnerPayload(snapshotJson) -> ObjectNode`. Recursively walks stages→activities→`config`/`validation`/`feedback`, removes keys in `DraftSchema.LEARNER_HIDDEN_KEYS` (leaf-name match), drops `validation` nodes that encode answer shape (keep `kind` only). Also used by preview (input = `draft_json`, same walker).
  - `lesson/application/LessonPublishService.java` — `publish(lessonId, expectedRowVersion, adminId)` flow:
    1. `lessons.findByIdForUpdate` (pessimistic lock)
    2. Reject `ARCHIVED`; allow `DRAFT` or `PUBLISHED`
    3. `expectedRowVersion` check
    4. Reuse readiness logic from `LessonService#checkPublishReadiness` (extract the error-list builder into a package-private method or a shared `PublishReadinessEvaluator` component — no duplication)
    5. If errors → throw `DraftValidationException` (existing handler returns 422 `DRAFT_SCHEMA_INVALID` + `details.errors[]`)
    6. `versionNo = (max existing)+1`, build snapshot, `lesson_versions.save` (new `LessonVersion` entity), `lesson.setCurrentVersionId`, `setStatus(PUBLISHED)`, `setUpdatedBy(adminId)`, save lesson
    7. Return `PublishResponse` DTO
  - `lesson/api/LearnerLessonController.java` — `/api/v1/lessons/...` endpoints (public read).
  - `lesson/api/AdminLessonVersionController.java` — `/api/v1/admin/lessons/{id}/versions[...]` endpoints.
  - DTO records: `PublishRequest`, `PublishResponse`, `LessonVersionSummary`, `LessonVersionDetail` (snapshot as `JsonNode`), `LearnerLessonMetadata`, `LearnerLessonContent` (snapshot as `JsonNode`), `LearnerLessonListItem`.
- **Modified components**
  - `LessonService`: remove TASK-0010 stub from `publish()` — delegate to `LessonPublishService` (or move publish into `LessonPublishService` and have `AdminLessonController` call it directly). Refactor `checkPublishReadiness` so the error-collection logic lives in a shared bean (e.g. `PublishReadinessEvaluator.evaluate(Lesson)`) used by both `/validate` and `/publish`.
  - `AdminLessonController`: add `POST /{id}/publish` (delegates to `LessonPublishService`), `POST /{id}/preview`.
  - `LessonRepository`: add `@Lock(PESSIMISTIC_WRITE) @Query("select l from Lesson l where l.id=:id") Optional<Lesson> findForUpdate(UUID id)`.
  - `LessonVersionRepository`: add `findByLessonIdOrderByVersionNoDesc(UUID lessonId, Pageable)` and `findByLessonIdAndId(lessonId, versionId)` and `findTopByLessonIdOrderByVersionNoDesc` (exists).
  - `ErrorCode`: add `LESSON_NOT_PUBLISHED`, `VERSION_NOT_FOUND`.
  - `GlobalExceptionHandler`: handlers for `LessonNotPublishedException` → 404, `VersionNotFoundException` → 404.
  - `SecurityConfig`: permit `GET /api/v1/lessons`, `/api/v1/lessons/*`, `GET /api/v1/events/*/lessons`.
- **No new Flyway migration** — schema already supports everything (V3 `lesson_versions` + immutable trigger + unique `(lesson_id,version_no)`).

## Related Code Files

**Modify**
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LessonService.java` — drop stub publish, extract readiness evaluator
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/AdminLessonController.java` — add `/publish`, `/preview`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/infrastructure/persistence/LessonRepository.java` — `findForUpdate`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/infrastructure/persistence/LessonVersionRepository.java` — finder methods
- `dau-viet-backend/src/main/java/com/dauviet/common/error/ErrorCode.java` — new codes
- `dau-viet-backend/src/main/java/com/dauviet/common/error/GlobalExceptionHandler.java` — new handlers
- `dau-viet-backend/src/main/java/com/dauviet/common/config/SecurityConfig.java` — permit-all for public lesson GETs

**Create**
- `lesson/application/LessonPublishService.java` — orchestrator
- `lesson/application/PublishReadinessEvaluator.java` — extracted shared evaluator (used by `/validate` + `/publish`)
- `lesson/application/LearnerProjectionService.java` — learner-safe projector
- `lesson/application/LessonVersionQueryService.java` — list/get versions (admin + learner-current)
- `lesson/draft/SnapshotBuilder.java` — build `snapshot_json` (embeds evidence + asset metadata)
- `lesson/api/AdminLessonVersionController.java` — `/api/v1/admin/lessons/{id}/versions`
- `lesson/api/LearnerLessonController.java` — `/api/v1/lessons/...`
- `lesson/api/dto/PublishRequest.java`, `PublishResponse.java`, `LessonVersionSummary.java`, `LessonVersionDetail.java`, `LearnerLessonMetadata.java`, `LearnerLessonContent.java`, `LearnerLessonListItem.java`
- `lesson/domain/LessonNotPublishedException.java`, `lesson/domain/VersionNotFoundException.java`

**Tests (Testcontainers ITs — pattern from `AdminLessonValidateIT`)**
- `dau-viet-backend/src/test/java/com/dauviet/lesson/AdminLessonPublishIT.java` — happy path, validation 422, version increment, concurrent publish safety, ARCHIVED blocked, republish on PUBLISHED, immutability trigger verifies UPDATE/DELETE on `lesson_versions` rejected, `EVIDENCE_IN_USE` LIKE-scan still triggers on embedded evidence ids.
- `dau-viet-backend/src/test/java/com/dauviet/lesson/LearnerLessonApiIT.java` — list/get metadata, learner projection strips `correctOptionIds`/`correctPairs`/`requiredEvidenceIds`, unpublished → 404, anonymous public access OK.
- `dau-viet-backend/src/test/java/com/dauviet/lesson/AdminLessonPreviewIT.java` — preview returns learner-safe shape from draft, no write.
- `dau-viet-backend/src/test/java/com/dauviet/lesson/AdminLessonVersionIT.java` — list/get/current version APIs.
- `dau-viet-backend/src/test/java/com/dauviet/lesson/LearnerProjectionServiceTest.java` — unit tests (no Spring) for hidden-key stripping.

## Implementation Steps

1. Extract `PublishReadinessEvaluator` from `LessonService.checkPublishReadiness` (keeps `/validate` behavior identical — always 200 + `{ready,errors,warnings,summary}`).
2. Add `ErrorCode.LESSON_NOT_PUBLISHED`, `VERSION_NOT_FOUND`; add domain exceptions + handlers.
3. Add `LessonRepository.findForUpdate` (pessimistic lock) and new `LessonVersionRepository` finders.
4. Implement `SnapshotBuilder` — collect referenced evidence ids (stage `requiredEvidenceIds` + activity `evidenceRefs` + activity `config` refs like `visibleEvidenceIds`), fetch `Evidence` rows, fetch `Asset` rows by evidence `assetId` + asset refs in config; emit `evidence[]` and `assetMeta[]` blocks in snapshot. Keep `stages[]`/`completion` verbatim.
5. Implement `LearnerProjectionService` — recursive walk removing `LEARNER_HIDDEN_KEYS` from `config`/`validation`/`feedback`; reduce `validation` objects to non-answer shapes (whitelist per validator type if needed; keep simple: strip the key list only).
6. Implement `LessonPublishService.publish` orchestration per Architecture section.
7. Wire `AdminLessonController` `/publish` + `/preview` (delegating appropriately).
8. Implement `AdminLessonVersionController` (list/get/current).
9. Implement `LearnerLessonController` + `SecurityConfig` public matchers.
10. Update `docs/API_SPEC.md` (`/publish`, `/preview`, `/versions`, `/lessons/{id}`, `/lessons/{id}/content`, `/events/{id}/lessons` marked implemented) and `docs/DATABASE_DESIGN.md` (snapshot contract firmed).
11. Write the 5 test classes listed above; run `mvnw verify` — all existing + new tests green.

## Todo List

- [x] Extract `PublishReadinessEvaluator`; `checkPublishReadiness` delegates to it (no behavior change)
- [x] Add `ErrorCode`s, exceptions, handlers
- [x] `LessonRepository.findForUpdate` + `LessonVersionRepository` finders
- [x] `SnapshotBuilder` + `LearnerProjectionService` (+ unit tests)
- [x] `LessonPublishService.publish` (transactional, locked, validated, inserts version, updates lesson)
- [x] Admin endpoints: `/publish`, `/preview`, `/versions`, `/versions/{id}`, `/versions/current`
- [x] Learner endpoints: `/lessons/{id}`, `/lessons/{id}/content`, `/events/{id}/lessons` (+ SecurityConfig)
- [x] ITs (5 classes: AdminLessonPublishIT, AdminLessonVersionIT, AdminLessonPreviewIT, LearnerLessonApiIT, LearnerProjectionServiceTest) all green; regression suite green — mvnw verify: 63 unit + 109 IT = 172 tests, 0 failures
- [x] Docs updated (API_SPEC + DATABASE_DESIGN)
- [ ] `tasks/TASK-0010/task.json` status flip to `done` after code-reviewer pass

## Success Criteria

- `POST /admin/lessons/{id}/publish` on valid DRAFT → 200 with `versionNo=1`, `lesson_versions` row exists, `lessons.status=PUBLISHED`, `current_version_id` set, all in one tx.
- Concurrent publishes on same lesson produce distinct `version_no` (no 500, no constraint violation surfacing).
- Publishing an ARCHIVED lesson → 409 `INVALID_STATUS_TRANSITION`.
- Publish with PUBLISH-level validation errors → 422 `DRAFT_SCHEMA_INVALID` + `details.errors[]` with path/code/message (same shape as `/validate`).
- Republish on `PUBLISHED` → new version; old `lesson_versions` row untouched (immutability trigger enforces).
- `GET /api/v1/lessons/{id}/content` on published lesson → learner payload has **no** `correctOptionIds`, `correctPairs`, `correctOrder`, `expectedOrder`, `requiredEvidenceIds` (inside `config`), `expectedHypothesis`, `answerKey`, `answer`, `key`, `expected` anywhere.
- `POST /admin/lessons/{id}/preview` returns the same learner-safe shape derived from `draft_json`, without writing `lesson_versions`.
- Public anonymous access to learner GETs works; LEARNER role on `/admin/**` → 403; anonymous on `/admin/**` → 401.
- Snapshot embeds evidence fields (id,title,type,description,source{*},reliability,relevance) so `EVIDENCE_IN_USE` archive guard still finds referenced ids.
- `mvnw verify` exit 0 with all existing ITs still green.

## Risk Assessment

- **Snapshot size**: embedding full evidence text per version could bloat `snapshot_json`. Mitigation: embed only the agreed learner-facing fields; do not copy `asset` blobs — only metadata.
- **Projection leaks**: missing a hidden key in the walker leaks answer keys. Mitigation: recursive leaf-name matching against `DraftSchema.LEARNER_HIDDEN_KEYS` + unit tests that seed drafts containing every hidden key and assert absence post-projection; IT checks real payload.
- **Lock contention**: `findForUpdate` blocks concurrent edits on the same lesson row. Acceptable — publish is rare and edits already serialize on `row_version`.
- **`EVIDENCE_IN_USE` LIKE-scan**: still works because we embed ids verbatim; add a regression IT asserting archive refuses after publish.
- **Draft-validation failure shape mismatch** between `/validate` (200 ready=false) and `/publish` (422). Decision: `/publish` throws `DraftValidationException` → 422 with `details.errors[]`, matching the `POST .../draft` 422 shape.

## Security Considerations

- Admin endpoints remain `hasRole("CONTENT_ADMIN")` via `/api/v1/admin/**` matcher.
- Learner endpoints added to `permitAll` list (`GET` only).
- Answer keys / hidden rubric never emitted — enforced by `LearnerProjectionService` + IT assertions (AGENTS.md invariant).
- `published_by` recorded from JWT `sub`; publish flow validates `expectedRowVersion` when provided.
- No PII added; no new secrets. `Idempotency-Key` on publish is **deferred** (see Open Qs) — risk of duplicate publish on retry is bounded by unique `(lesson_id,version_no)` (retry would create v+1, not fail).

## Next Steps / Open Questions

- TASK-0011+: `POST /attempts` flow + learner fetch of pinned `lesson_version_id` (authorize by attempt.user_id == jwt.sub).
- Idempotent publish (`idempotency_records` wiring) — defer to a task that owns submission/completion idempotency so one service handles all `Idempotency-Key` semantics.
- Confirm with PO: publish lesson while parent event still `DRAFT` — currently allowed with warning; tighten to block if required.
- Confirm learner API needs pagination on `/events/{id}/lessons` (currently returns full list — typical event has ≤ 10 lessons).
