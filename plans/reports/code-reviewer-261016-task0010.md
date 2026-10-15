# Code Review — TASK-0010 Lesson Publishing, Versioning & Learner-Safe Content API

Reviewer: code-reviewer
Date: 2026-10-16
Plan reviewed: `plans/261016-0005-task0010-lesson-publish/plan.md`
Spec: `tasks/TASK-0010/task.json` (AC-1..AC-11)
Scope: `dau-viet-backend/` — all uncommitted changes on `main`

## Overall Assessment

The implementation is solid and matches the plan's architecture. Transactional publish is correct (pessimistic lock → version_no=max+1 → insert → rotate `current_version_id` in one tx). The learner projection is deep-copy + strip and has strong unit coverage (7 tests covering nested arrays, validation-subtree, non-mutation). Snapshot embedding satisfies the EVIDENCE_IN_USE regression. Admin/learner endpoints, DTOs, handlers and SecurityConfig wiring are consistent with prior conventions. Test count: 170 (61 unit + 109 IT) all green.

However, **AC-2 is materially under-implemented**. The spec requires "event must be PUBLISHED; template must exist, be enabled, and schema_version must match". `PublishReadinessEvaluator` checks only `templateId` existence + `schemaVersion` — it never inspects `event.status` (not even as a warning, despite the plan's decision to make it warn-only) and never inspects `template.enabled`. This is not a "deferred open question" — it is silent non-enforcement of an AC-2 invariant and contradicts the plan's own claim of "warn, do not block".

## Critical Issues

None. No answer-key leaks found in learner paths, no SQL/serializer bypass, no broken transaction boundary, no missing auth guard.

## High Priority

### P1-1. Event-PUBLISHED gating is absent, not warn-only (AC-2 violation)

`PublishReadinessEvaluator.evaluate` never queries `historical_events` and emits no warning when `lesson.event.status != PUBLISHED`. The plan explicitly states warn-not-block; the implementation does neither. The publish tests seed `historical_events.status='DRAFT'` (e.g. `AdminLessonPublishIT.java:73`) and succeed — confirming silent non-enforcement.

- File: `dau-viet-backend/src/main/java/com/dauviet/lesson/application/PublishReadinessEvaluator.java` lines 44–91 — no `HistoricalEventRepository` is injected or consulted.
- Fix: inject `HistoricalEventRepository`, emit `EVENT_NOT_PUBLISHED` as a warning (per plan) or as an error (per AC-2 strict reading). Decision required from PO; either way the check itself must exist. Sample:

```java
events.findById(l.getEventId()).ifPresent(ev -> {
    if (ev.getStatus() != EventStatus.PUBLISHED) {
        warnings.add(Map.of("code", "EVENT_NOT_PUBLISHED",
                "message", "parent event status is " + ev.getStatus()));
    }
});
```

### P1-2. `template.enabled` not checked at publish time (AC-2 violation)

`PublishReadinessEvaluator` only checks `tpl == null` and `schemaVersion`. A disabled template still allows publish. `LessonService.create`/`update` correctly enforce `enabled`, but the readiness path skips it. AC-2 requires it.

- File: `dau-viet-backend/src/main/java/com/dauviet/lesson/application/PublishReadinessEvaluator.java` lines 62–73.
- Fix: after the `tpl == null` branch, add:

```java
else if (!Boolean.TRUE.equals(tpl.getEnabled())) {
    errors.add(Map.of("path", "templateId",
            "code", "TEMPLATE_DISABLED", "message", "template disabled"));
}
```

`TEMPLATE_DISABLED` ErrorCode already exists (mapped to 422 in `GlobalExceptionHandler` line 137–139) — reuse it.

## Medium Priority

### P2-1. `LearnerLessonService.getMetadata` returns `versionNo=0` on inconsistency

`LessonService.getMetadata` (`LearnerLessonService.java:69–73`) calls `versions.findById(l.getCurrentVersionId())` and maps `null → 0/null publishedAt`. If the join row is missing (data corruption or replication lag) the API returns `versionNo=0`, which is not a real version and silently masks corruption. `loadPublished` already guards `currentVersionId == null`; a missing joined row should 404 (`VERSION_NOT_FOUND`) or 500, not pretend.

- File: `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LearnerLessonService.java:67–74`.
- Fix: `.orElseThrow(() -> new VersionNotFoundException("current version missing for lesson " + lessonId))`.

### P2-2. `LearnerLessonService.parse` swallows JSON parse errors

`parse` (`LearnerLessonService.java:96–102`) catches `Exception` and returns `createObjectNode()`. A corrupt `snapshot_json` row silently produces `{content:{}}` for every learner — invisible operationally. Same pattern in `LessonVersionQueryService.parse` (admin path; lower risk).

- File: `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LearnerLessonService.java:96–102`.
- Fix: log at ERROR with `traceId`/`lessonVersionId` and rethrow (e.g. `IllegalStateException`) so `handleGeneric` returns a 500 the team can alert on. At minimum, log loudly.

### P2-3. `activity.evidenceRefs` survives the learner projection

`LearnerProjectionService` strips hidden leaf names and the entire `validation` node, but `ACTIVITY_KEYS` includes `evidenceRefs` (TASK-0009 schema), which is not in `LEARNER_HIDDEN_KEYS` and not in `ACTIVITY_SERVER_ONLY`. The field survives into the learner payload. `evidenceRefs` enumerates the IDs of evidence items the activity uses — these IDs are already public via `evidence[]`/`visibleEvidenceIds`, so no real leak today, but the field is redundant with `visibleEvidenceIds` and conceptually server-side bookkeeping ("which evidence items feed this activity's correct/incorrect logic").

- File: `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LearnerProjectionService.java:21–26`.
- Fix: add `"evidenceRefs"` to `ACTIVITY_SERVER_ONLY`, OR document explicitly in `DraftSchema` that `evidenceRefs` is intended learner-visible.

### P2-4. `SnapshotBuilder` uses a private static `ObjectMapper`, not the Spring bean

`SnapshotBuilder.MAPPER` (line 36) is a raw `new ObjectMapper()`. Elsewhere (`LessonPublishService`, `PublishReadinessEvaluator`, `LearnerLessonService`) the injected bean is used. If Spring-configured Jackson modules/mixins ever matter (e.g. Java Time, Parameter Names), snapshot output may diverge from draft parsing behavior.

- File: `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/SnapshotBuilder.java:36,41`.
- Fix: inject the Spring `ObjectMapper` via constructor, remove the static `MAPPER`.

### P2-5. `collectAssetIds` uses deprecated `JsonNode.withArray`

`SnapshotBuilder.java:93` iterates `snapshot.withArray("evidence")`. `withArray` is deprecated for removal in Jackson 3.x and is also a mutation API (creates the array if missing). Iterating a freshly-populated array via `(ArrayNode) snapshot.get("evidence")` is clearer and future-proof.

## Low Priority

### P3-1. `PageResponse` size==0 edge — `totalPages` guard is defensive but unreachable

`LessonVersionQueryService.list` line 49: `pageable.getPageSize() == 0 ? 0 : ...` — `@Min(1)` on the controller prevents `size=0`, so the guard is dead code. Keep for safety; no action needed.

### P3-2. `/api/v1/events/{eventId}/lessons` has no ordering

`lessons.findByEventIdAndStatus(eventId, PUBLISHED)` returns lessons in unspecified order. For a stable learner UX the list should order by `createdAt ASC` or `title ASC`.

- File: `dau-viet-backend/src/main/java/com/dauviet/lesson/infrastructure/persistence/LessonRepository.java:26` and `LearnerLessonService.java:59`.
- Fix: rename finder to `findByEventIdAndStatusOrderByCreatedAtAsc` (or add `OrderBy` clause).

### P3-3. `SnapshotBuilder` iterates `findAllById` in unspecified order

`embedEvidence`/`embedAssets` iterate `findAllById` results in whatever order JPA returns. Snapshot content is functionally equivalent (lookup by id), but stable ordering would make snapshots deterministic and diff-friendly. Order `evidence[]` by the order IDs first appear in the draft (the `LinkedHashSet` already preserves that order — just `findAllById` does not honour it).

- Fix: build `Map<UUID,Evidence> byId = Streams...`, then iterate `ids` (LinkedHashSet) and look up. Same for assets.

### P3-4. `LessonPublishService.publish` doesn't reset `objectivesJson`/`draftJson`

Not a bug — republish correctly re-reads `lesson.getDraftJson()` each time. Noted only because the snapshot copies `objectivesJson` and stages verbatim, so an admin must `PUT /draft` + `PATCH` objectives before republish to change them. Documented behaviour matches plan.

## Edge Cases Found by Scout

- `version_no` collision: covered — pessimistic lock + `UNIQUE(lesson_id,version_no)` + dense-1..N assertion in `publish_concurrent_singleWinner_noVersionNoCollision`.
- `lesson_versions` UPDATE/DELETE: covered — DB trigger + IT `lessonVersions_immutableTrigger_blocksUpdateAndDelete`.
- EVIDENCE_IN_USE LIKE-scan on snapshot: covered — `evidenceArchive_blockedWhenEmbeddedInPublishedSnapshot`.
- ARCHIVED publish: covered — `publish_archived_409`.
- Stale `expectedRowVersion`: covered — `publish_staleExpectedRowVersion_409`.
- Anonymous + LEARNER role on `/admin/**`: covered — `publish_anon401_learner403` / `versions_anon401_learner403` / `preview_anon401_learner403`.
- DRAFT event listing: covered — `listForEvent_draftEvent_404`.
- Unpublished lesson reads: covered — `learnerEndpoints_unpublishedLesson_404` returns `LESSON_NOT_PUBLISHED` correctly.
- Missing lesson: covered — `learnerEndpoints_missingLesson_404` returns `LESSON_NOT_FOUND`.
- Preview strips hidden keys + no version row + status stays DRAFT: covered — `preview_stripsHiddenKeys_andDoesNotWriteVersion`, `preview_stripsAnswerKeysFromDraft`.
- Admin sees full snapshot incl. server-only keys: covered — `get_returnsFullSnapshotIncludingServerOnlyKeys`.
- Hidden key inside `config` deep array / rubric / validation subtree: covered — `stripsHiddenKeysNestedInArrays`, `stripsHiddenKeysInValidationSubtreeAndDeepArrays`.
- **Not covered**: publishing when `template.enabled=false` — no IT exists for this path; AC-2 not enforced (P1-2).
- **Not covered**: publishing on `DRAFT` event — every test uses DRAFT-event fixtures and they all succeed, confirming silent bypass (P1-1).

## Positive Observations

- Snapshot design is clean: `evidence[]`/`assets[]` embedded denormalized so admin edits cannot retroactively mutate a published version, AND `EVIDENCE_IN_USE` LIKE-scan continues to work via embedded IDs. Solid decision.
- `LessonPublishService.publish` is properly `@Transactional`, takes a real pessimistic lock, and rolls back cleanly on `DraftValidationException` (unchecked → default rollback).
- `LearnerProjectionService` deep-copies before stripping — the input `JsonNode` is never mutated (asserted by `doesNotMutateInput`). Hidden-key leaf-name match avoids substring false-positives (`correctOptionIdsX` survives).
- `checkPublishReadiness` correctly delegates to `PublishReadinessEvaluator` — the `/validate` contract (always 200 with `{ready,errors,warnings,summary}`) is preserved.
- `AdminLessonController.preview` is read-only (`@Transactional(readOnly=true)` in service) and returns `versionNo/lessonVersionId=null` — verified in IT.
- `LearnerLessonService.listForEvent` hides non-PUBLISHED events as `ResourceNotFoundException` → `EVENT_NOT_FOUND` envelope — preserves the "don't leak unpublished event exists" pattern.
- DTO records are minimal and well-named; `LearnerLessonListItem` exposes only `id/title/centralQuestion` (no draft content even accidentally).
- `AdminLessonVersionController` uses `@Min/@Max` bounds on `page`/`size` — consistent with `AdminLessonController`.
- `GlobalExceptionHandler` consistently maps new domain exceptions to the `{code,message,details,traceId}` envelope without leaking stack traces.
- `PublishReadinessEvaluator` never throws on unparseable draft — reports `INVALID_DRAFT` as error and returns early; defensive.

## Recommended Actions (priority order)

1. **P1-1 + P1-2 (blocker for AC-2)**: add `template.enabled` check as an error in `PublishReadinessEvaluator`; add `event.status` check (error per AC-2 strict, warning per plan). Decide event-gating policy with PO and either implement or explicitly document the deferral in `tasks/TASK-0010/task.json` nextAction + AC evidence.
2. **P2-1**: throw `VersionNotFoundException` instead of returning `versionNo=0` in `LearnerLessonService.getMetadata`.
3. **P2-2**: log + rethrow on `snapshot_json` parse failure in `LearnerLessonService.parse` (and `LessonVersionQueryService.parse` while at it).
4. **P2-3**: decide whether `activity.evidenceRefs` should be learner-visible; either strip via `ACTIVITY_SERVER_ONLY` or document the intent.
5. **P2-4**: inject Spring `ObjectMapper` into `SnapshotBuilder`; remove the static `MAPPER`.
6. **P2-5**: replace deprecated `JsonNode.withArray` with `(ArrayNode) snapshot.get("evidence")`.
7. **P3-2**: add `OrderBy createdAt ASC` to `findByEventIdAndStatus` for stable learner listing.
8. **P3-3**: preserve `LinkedHashSet` order in `embedEvidence`/`embedAssets` by iterating `ids` after building an id→entity map.
9. **Tests to add** (once P1-1/P1-2 fixes land):
   - `publish_disabledTemplate_422` (or 409 per mapping).
   - `publish_draftEvent_*` — either `publish_draftEvent_422` (if blocking) or assert warning `EVENT_NOT_PUBLISHED` appears in `/validate` warnings while publish still succeeds.
10. Update `tasks/TASK-0010/task.json` `acEvidence.AC-2` to reflect the actual implementation state (currently over-claims).

## Metrics

- New tests: 27 ITs (10 publish + 6 version + 4 preview + 7 learner) + 7 unit (projection) = 34 new.
- Total suite: 61 unit + 109 IT = 170, all green.
- Files added: ~17 production + 5 test classes. LOC kept tight; no file >200 lines.
- Type coverage: N/A (Java).
- Linting: not run by reviewer; relies on `mvnw verify` clean compile + tests.
- AC coverage: 9/11 fully evidenced. **AC-2 (event/template eligibility) under-implemented. AC-9 partially evidenced** (immutability trigger tested; "no UPDATE on learner_attempts" vacuously true — no `learner_attempts` write path exists yet, deferred to learning-engine task).

## Unresolved Questions

1. AC-2 strictness: should `event.status != PUBLISHED` block publish (spec literal) or warn-only (plan's documented choice)? Implementation currently does neither — must be reconciled.
2. Is `activity.evidenceRefs` intended to be learner-visible? If yes, add a comment in `DraftSchema` to that effect; if no, add to `ACTIVITY_SERVER_ONLY`.
3. `/api/v1/events/{id}/lessons` ordering: by `createdAt` (publish order) or `title`? Spec is silent.
4. `SnapshotBuilder` `findAllById` order — deterministic snapshot ordering (nice-to-have for diffs) vs. current unspecified order (functionally OK)?
5. AC-9's "does not touch existing learner attempts' pinned version" is vacuously satisfied — `learner_attempts` has no write path yet. Should the AC be re-scoped to TASK-0011 (attempts flow) where pinning actually exists?
