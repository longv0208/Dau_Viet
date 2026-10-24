# Phase 03 — API + Completion Pipeline Integration

## Context Links

- Brief sections 7 (atomic completion), 10 (progress API), 11 (dossier APIs), 17 (scenarios A-J).
- `LearnerAttemptService.doComplete()` lines 431-475 — insertion point at line ~471 after `itemUnlocks.evaluateAfterLessonCompletion` inside `if (completedVersion != null)`.
- `CollectionController` — `/api/v1/me/collection` existing routes; literal `/dossiers` path must be declared before/orthogonal to `/{evidenceId}` (Spring prefers literal match — safe, but keep mappings explicit).
- `JwtSubjectExtractor` — existing JWT -> userId pattern used by CollectionController.
- Contract section 11 API table line 255-256.

## Overview

- Priority: P1.
- Status: pending.
- Wire `EventMilestoneRecorder` into completion tx; add `EventProgressController` + dossier endpoints in collection package.

## Key Insights

- `complete()` is wrapped in `idempotency.execute(userId,"COMPLETE_ATTEMPT",key,...)` — replay short-circuits BEFORE doComplete, so milestone code inside doComplete is naturally replay-safe; ALSO `ON CONFLICT DO NOTHING` covers non-idempotent-key edge cases (e.g., replay after response loss with new key).
- Insertion AFTER rewardGrants + itemUnlocks keeps lock order: attempt row lock (pessimistic) -> reward/item writes -> event advisory lock -> milestone + unlock inserts. Same transaction — scenario J rollback safety free.
- `completedVersion.getLessonId()` -> `lessons.findById` -> `getEventId()` may be null (lessons can be event-less) — guard null; skip evaluation quietly.
- Failure in recorder must NOT swallow completion: wrap in try/catch? NO — brief requires atomicity: dossier grant failure must roll back the whole completion (scenario J). So let exceptions propagate; reconciliation-on-read covers retry.
- `unlockedDossiersCount` in progress response = count of user_dossier_unlocks joined to event_dossiers of this event for this user.

## Requirements

`GET /api/v1/me/events/{eventId}/progress`:
- Auth via `@AuthenticationPrincipal Jwt` + `JwtSubjectExtractor`.
- 404 when event absent (`HistoricalEventRepository.existsById` check) — do not leak via uniform 404.
- Response shape per brief section 10: eventId, status (NOT_CONFIGURED|IN_PROGRESS|EVENT_COMPLETED|EVENT_MASTERED), policyVersion nullable, requiredLessonsTotal/Completed, eventCompleted, eventMastered, masteryThreshold, requiredLessons[] {lessonId,title,required,completed,masteryStatus,bestKnowledgeScore}, unlockedDossiersCount.
- status precedence: EVENT_MASTERED row exists -> EVENT_MASTERED; else EVENT_COMPLETED row -> EVENT_COMPLETED; else if policy -> IN_PROGRESS; else NOT_CONFIGURED.
- Never return score for NOT_ASSEDSED lessons — bestKnowledgeScore null then.
- Reconcile-on-read inside service tx (see phase 2 step 8).

`GET /api/v1/me/collection/dossiers`:
- Params: type (PERSON|LOCATION|ARTIFACT|CONTEXT), eventId, unlocked (bool, optional), page, size (cap 50 — same MAX_PAGE_SIZE convention).
- Visible set: dossiers with status PUBLISHED, PLUS user's own unlocked ARCHIVED dossiers (still readable — brief 11.4); exclude DRAFT entirely.
- Each item: dossierId, canonicalCode, dossierType, title, shortDescription/previewDescription, assetId, eventIds[] (via event_dossiers), unlocked bool, grantedAt when unlocked, unlockEventId (provenance), preview true for locked.
- Stable sort: `ORDER BY d.title ASC, d.id ASC` (or created_at,id) — deterministic pagination.

`GET /api/v1/me/collection/dossiers/{dossierId}`:
- DRAFT -> 404 (invisible, cannot guess-id probe: 404 not 403).
- PUBLISHED + locked -> preview fields only (id, canonicalCode, type, title, previewDescription, assetId, unlocked=false, event links). No detail_description, no source_json internals? Brief says preview allowed "title/preview" — return source title-level metadata optional; keep detail + full source for unlocked.
- PUBLISHED/ARCHIVED + unlocked -> full detail incl. sourceJson citations, grantedAt, unlock event, dossierVersion snapshot note.

Negative rules:
- No endpoint returns another user's data — all queries filter userId from JWT.
- No POST claim endpoint (brief 16).
- Evidence endpoints unchanged.

## Architecture

`EventProgressController` (`com.dauviet.collection.api` or `historicalevent.api`? — path is `/me/events/...` user-scoped; place in `collection.api` alongside dossier controller to keep ownership of new feature in one module) — decide `collection.api.EventProgressController`. `DossierController` separate class `@RequestMapping("/api/v1/me/collection/dossiers")` — no clash with `/{evidenceId}` because literal segment wins, and separate controller keeps files <200 lines.

## Related Code Files

Modify:
- `dau-viet-backend/.../learning/application/LearnerAttemptService.java` — inject `EventMilestoneRecorder` (+ `LessonRepository` already present); in `doComplete` after line 471 add:
  ```java
  UUID eventId = lessons.findById(lessonId).map(Lesson::getEventId).orElse(null);
  if (eventId != null) {
      eventMilestones.recordCompletion(userId, eventId);
  }
  ```
  (lessonId already resolved line 468.)
- Optionally `CompleteAttemptResponse` — add `newlyUnlockedDossiers` list field (additive, contract-safe) so Flutter can show gentle cue without extra call. Decide: YES additive field, brief 16 allows "response contract additive".

Create:
- `collection/api/EventProgressController.java`
- `collection/api/DossierController.java`
- `collection/api/dto/EventProgressResponse.java`, `RequiredLessonProgressDto.java`, `DossierSummaryResponse.java`, `DossierDetailResponse.java`, `DossierSourceDto.java`
- `collection/application/DossierService.java` (list/detail visibility rules)
- `collection/api/mapper/DossierMapper.java` if mapping non-trivial

## Implementation Steps

1. Inject `EventMilestoneRecorder` into `LearnerAttemptService` constructor; add eventId resolution + call in doComplete inside `completedVersion != null` block.
2. Add `newlyUnlockedDossiers` (List<String> ids or minimal summaries) to `CompleteAttemptResponse` — returned from recorder; replay path returns empty list (idempotent: stored response replays anyway).
3. `EventProgressController.progress(eventId, jwt)` -> `EventProgressQueryService.progressOf`.
4. `DossierService.list` — build specification/query: `status='PUBLISHED' OR (status='ARCHIVED' AND exists unlock for user)`; filters type/eventId (event join via event_dossiers)/unlocked flag; map each row: unlocked = exists in user_dossier_unlocks.
5. `DossierService.detail` — load by id; DRAFT -> ResourceNotFoundException; locked PUBLISHED -> preview DTO; unlocked (any status) -> full DTO; locked ARCHIVED -> 404 (cannot open new archived; also invisible unless owned — brief 11.4 "khong mo moi dossier bi archive" + DRAFT-like invisibility for non-owners is the safe reading).
6. Controllers wire with same pagination cap + JWT pattern as CollectionController.
7. Verify route resolution: `/me/collection/dossiers/abc` hits DossierController not `/{evidenceId}` — add IT in phase 5.
8. Compile + boot smoke.

## Todo List

- [ ] LearnerAttemptService: inject recorder, eventId resolution, call site
- [ ] CompleteAttemptResponse additive newlyUnlockedDossiers
- [ ] EventProgressController + response DTOs
- [ ] DossierController list endpoint + filters + pagination
- [ ] DossierController detail endpoint + visibility rules
- [ ] DossierService visibility logic
- [ ] Route non-clash check (manual + IT planned phase 5)
- [ ] `mvnw compile` clean

## Success Criteria

- Progress endpoint returns NOT_CONFIGURED for event without policy; correct counts otherwise.
- Completing last required lesson grants EVENT_COMPLETED + unlocks dossiers in same tx (visible in progress + list immediately).
- Replay complete returns identical response, no duplicate rows.
- DRAFT dossier 404s for everyone; locked PUBLISHED returns preview only; unlocked ARCHIVED readable by owner.

## Risk Assessment

- Tx growth in doComplete: recorder adds 2-4 queries + advisory lock — acceptable; keep queries indexed (required ids IN-list, unlock insert select).
- Deadlock: two users same event -> locks are per (user,event), no cross-user contention; same user two lessons -> serialized by advisory lock AFTER attempt locks — ordering consistent since attempt ids differ but lock order attempt->event always.
- eventId null lessons -> skip; log debug not error.
- Exception mid-recorder -> whole complete tx rolls back (desired per scenario J) but learner sees 500 instead of completion; acceptable — retry heals; document in report.

## Security Considerations

- All endpoints JWT-authenticated; userId never from path/param.
- DRAFT/locked detail leak prevention: whitelisted preview fields only.
- No PII in dossier data.

## Next Steps

- Phase 4 Flutter consumes these endpoints; phase 5 tests scenarios A-J.
