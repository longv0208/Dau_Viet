# Phase 02 — Backend preview evidence enrichment

## Context Links

- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LessonService.java` (`preview()` at ~line 201)
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/SnapshotBuilder.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LessonPublishService.java` (calls `snapshots.build`)
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LearnerLessonService.java` (published content path)

## Overview

- Priority: P1
- Status: pending
- Enrich admin preview response with resolved `evidence[]` and `assets[]` so EVIDENCE_SELECT / VERIFICATION / VIEW_IMAGE renderers can display real content instead of raw UUID prefixes.

## Key Insights

- `SnapshotBuilder.build(lesson, draft, template)` already does exactly what we need: copies `stages`, embeds `evidence[]` + `assets[]` via `collectEvidenceIds` + `collectAssetIds`. Its only extra output fields are `lessonId`, `title`, `centralQuestion`, `objectives`, `templateCode`, `completion` — all harmless for preview.
- `LessonService.preview()` currently projects the bare draft — no `evidence`/`assets` keys at all.
- `LearnerLessonService.getContent()` already receives full snapshots (they include `evidence[]`/`assets[]` from `SnapshotBuilder.build`). So the learner path already has this data — only preview is missing it.
- Template lookup: `lesson.getTemplateId()` is always set on a valid lesson (NOT NULL FK). `templates.findById` returns Optional. If template is missing (data corruption), preview should still work — fall back to bare draft projection rather than 500.
- DECISION: **Reuse `snapshotBuilder.build()` in `preview()`**, then project the result through `learnerProjection.project()`. This is least invasive and keeps preview == published shape. If template lookup fails, fall back to `learnerProjection.project(draft)` (no evidence embed) — preview still renders, just without evidence docs.
- Alternative considered: extract `collectEvidenceIds`/`embedEvidence`/`embedAssets` into a shared helper. Rejected — `build()` already handles the full pipeline; extracting adds a new abstraction for no gain (YAGNI).

## Requirements

- `POST /admin/lessons/{id}/preview` returns `LearnerLessonContent.content` containing `evidence[]` and `assets[]` arrays alongside `stages[]`.
- Evidence entries must include: `id`, `title`, `evidenceType`, `description`, `source{title,author,url,citation,publishedAt}`, `reliability`, `relevance`, `assetId`.
- Asset entries must include: `id`, `storageKey`, `mimeType`, `sizeBytes`, `originalFilename`, `altText`.
- Snapshot `stages[]` remain unpolluted — `SnapshotBuilder.build` copies `draft.stages` by reference into snapshot; projection deep-copies before stripping, so no mutation risk.
- Published learner content (`getContent`) already works — no change needed there.

## Architecture

```
preview(lessonId):
  lesson = load(id)
  draft  = parse(lesson.draftJson)
  template = templates.findById(lesson.templateId).orElse(null)
  doc = (template != null)
        ? snapshotBuilder.build(lesson, draft, template)   // full shape w/ evidence+assets
        : draft                                            // fallback: bare draft
  return LearnerLessonContent(id, null, null, projection.project(doc))
```

## Related Code Files

Modify:
- `LessonService.java` — inject `SnapshotBuilder` + `LessonTemplateRepository` (already injected as `templates`); change `preview()` method.

Create: none. Delete: none.

## Implementation Steps

1. `LessonService.java`:
   - Add field `private final SnapshotBuilder snapshotBuilder;` and constructor param.
   - In `preview()`: after parsing `draft`, look up `LessonTemplate tpl = templates.findById(l.getTemplateId()).orElse(null);`
   - If `tpl != null`: `JsonNode enriched = snapshotBuilder.build(l, draft, tpl);` then `return new LearnerLessonContent(l.getId(), null, null, learnerProjection.project(enriched));`
   - If `tpl == null`: fall back to current behaviour `learnerProjection.project(draft)`.
2. No changes to `SnapshotBuilder`, `LearnerProjectionService`, `LearnerLessonService`, or `LessonPublishService`.
3. Unit test — add to existing test class (or new `LessonServicePreviewTest` if needed):
   - Mock `lessons`, `templates`, `evidences`, `assets` repos; call `preview()`; assert `content.evidence` and `content.assets` arrays are populated when draft references evidence ids.
   - Assert `content.stages[].activities[].config` still has hidden keys stripped.
   - Assert fallback: template missing → `content` still has `stages` but empty/absent `evidence`.
   - Note: `LessonService` tests may not exist yet. Check for `LessonServiceTest` / `LessonServiceIT`. If only IT exists, write a plain Mockito unit test for `preview()` only (no Spring context).

## Todo List

- [ ] `LessonService.preview()` calls `snapshotBuilder.build()` when template resolves
- [ ] Fallback to bare draft projection when template missing
- [ ] Unit test: preview returns evidence[] and assets[]
- [ ] Unit test: preview still strips hidden keys from activity configs
- [ ] Unit test: template-missing fallback does not throw

## Success Criteria

- `./mvnw test` — new preview tests pass; no regressions.
- Preview response JSON contains `evidence[]` and `assets[]` at top level.
- Published learner content unchanged (already has evidence from snapshot).

## Risk Assessment

- `SnapshotBuilder.build()` calls `evidences.findAllById` / `assets.findAllById` — extra DB reads per preview call. Acceptable: preview is admin-only, low frequency.
- If lesson was created before template enforcement and `templateId` is null → `findById(null)` may throw; guard with `l.getTemplateId() != null` check before lookup.
- `build()` puts `lessonId`/`title`/`templateCode` in the projected doc — harmless extra fields in preview response; frontend ignores unknown keys.

## Security Considerations

- Evidence `source.url` is emitted — it's already in the published snapshot for learners, so no new exposure.
- `requiredEvidenceIds` remains stripped by projection — no change.
- Preview endpoint is admin-authenticated; evidence embedding does not widen access.

## Next Steps

- Phase 03 wires `evidence`/`assets` into `PreviewActivityProps` so renderers can look up docs by id.
