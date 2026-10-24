# Phase 02 — Backend Domain, Persistence & Evaluation Engine

## Context Links

- Brief sections 6 (engine), 8 (dossier semantics), 17 (concurrency).
- Contract section 2.4, section 8 lines 214-218 (evaluation flow, EVENT_MASTERED rule, NOT_CONFIGURED, no-revoke).
- Business rules EVT-01..07, section 7.2 (NOT_ASSESSED, best valid result, threshold 70).
- Module placement: dossier tables belong to `com.dauviet.collection` (contract line 22).
- Reuse: `MapLocationUnlockQuery.completedLessonIds` (`dau-viet-backend/.../map/application/MapLocationUnlockQuery.java`), `GradedActivityClassifier.isGraded`, `LearnerAttemptRepository` join idiom (attempts x lesson_versions -> lesson_id).

## Overview

- Priority: P1.
- Status: pending.
- New code in `com.dauviet.collection` (domain entities, repos, dossier services) + `com.dauviet.learning.application` or new `com.dauviet.event` subpackage for progress engine. Decision: put event-progress classes in `com.dauviet.collection.application` only if they serve dossier reads; milestone/evaluation logic better lives in `com.dauviet.learning`? Contract section 2.4 lists event/milestone tables under "Event/Milestone (moi, GAME-04)" pointing to dossier unlock — simplest coherent choice per KISS: keep ALL new classes in `com.dauviet.collection` subpackages `domain`, `infrastructure.persistence`, `application` since contract assigns tables there and evaluation depends on collection-owned tables. Flag alternative in report if reviewer disagrees.

## Key Insights

- Evaluation must read pinned-snapshot graded status: for each required lesson, "graded" = pinned `lesson_versions.snapshot_json` of the user's best completed attempt has >=1 required activity where `GradedActivityClassifier.isGraded` true. Store no separate flag — derive per attempt.
- Best valid result: query `lesson_results.result_json->>'knowledgeScore'` max over user's COMPLETED attempts of that lesson; join attempts x lesson_versions to map version -> lesson.
- NOT_ASSESSED: required lesson completed but its best result's pinned snapshot has zero graded required activities -> mastery contribution neutral, never auto-pass.
- EVENT_MASTERED requires >=1 graded required lesson in policy AND every graded required lesson best score >= threshold AND event already COMPLETED. One-way: never delete milestone rows.
- Advisory lock key `"userId|eventId"` via `pg_advisory_xact_lock(hashtextextended(:k,0))` before evaluate+insert — serializes the two-last-lessons race (scenario C).
- All writes `INSERT ... ON CONFLICT DO NOTHING` via native query or `insertIgnore` idiom like `UserEvidenceRepository` — verify that repo's existing pattern before writing new ones.

## Requirements

Entities (package `com.dauviet.collection.domain`):
- `EventCompletionPolicy` — id, eventId, policyVersion, status enum `PolicyStatus{DRAFT,PUBLISHED,ARCHIVED}`, requiredLessonIds/optionalLessonIds as `String` jsonb via `@JdbcTypeCode(SqlTypes.JSON)` (project convention), masteryThreshold Integer, publishedAt, createdAt, updatedAt. Parse ids to `List<UUID>` in service via ObjectMapper.
- `UserEventProgress` — embedded id `UserEventProgressId(userId, eventId, milestone)`; fields policyVersion, requiredSnapshot jsonb string, grantedAt. Enum `EventMilestone{EVENT_COMPLETED,EVENT_MASTERED}`.
- `HistoricalDossier` — id, canonicalCode, dossierType enum `DossierType{PERSON,LOCATION,ARTIFACT,CONTEXT}`, title, shortDescription, previewDescription, detailDescription, sourceJson jsonb string, assetId, status enum `DossierStatus{DRAFT,PUBLISHED,ARCHIVED}`, version, createdAt, updatedAt.
- `EventDossier` — embedded id (eventId, dossierId), unlockOn, createdAt.
- `UserDossierUnlock` — embedded id (userId, dossierId), eventId, grantedAt, dossierVersion.

Repos (`com.dauviet.collection.infrastructure.persistence`):
- `EventCompletionPolicyRepository` — `Optional<...> findByEventIdAndStatus(eventId, PUBLISHED)`; `findByEventIdOrderByPolicyVersionDesc`.
- `UserEventProgressRepository` — derived finders + native `insertIgnore` (ON CONFLICT DO NOTHING) returning int rows-written.
- `HistoricalDossierRepository` — `findByCanonicalCode`, paged `findByStatusInAndType` etc. for list API; `findAllById` for fan-out batch.
- `EventDossierRepository` — `findByEventId` join fetch dossier where dossier.status='PUBLISHED'.
- `UserDossierUnlockRepository` — native `insertIgnore`, `existsByIdUserIdAndIdDossierId`, `findByIdUserId`, count by user + event-join query for `unlockedDossiersCount`.

Services (`com.dauviet.collection.application`):
- `EventCompletionPolicyService` — `Optional<PolicyView> publishedPolicy(eventId)` returning parsed record (eventId, version, requiredIds List<UUID>, optionalIds, threshold). NOT_CONFIGURED = empty optional. Validate-on-read: log warn if required list empty on PUBLISHED row.
- `EventProgressEvaluator` — pure-ish component: inputs (userId, policy, completedLessonIds set, bestScores map, gradedFlags map) -> outputs `Evaluation{milestoneToGrant: EVENT_COMPLETED|EVENT_MASTERED|none, perLesson list}`. Rules per contract 216 + rules 279: completed-all -> COMPLETED; mastered check only if >=1 graded required lesson and all graded required have bestScore >= threshold; ungraded required marked NOT_ASSESSED.
- `EventMilestoneRecorder` — `recordCompletion(userId, eventId)` called inside doComplete tx: advisory lock -> policy lookup (skip if absent) -> `completedLessonIds` check -> if all required completed: insert progress EVENT_COMPLETED (snapshot = required ids json), then evaluate mastery -> maybe insert EVENT_MASTERED, then dossier fan-out `INSERT INTO user_dossier_unlocks ... SELECT ... ON CONFLICT DO NOTHING` joined to `event_dossiers` filtered dossier PUBLISHED. Return `Set<UUID> newlyUnlockedDossierIds` for response/telemetry. Never throws on conflict.
- `EventProgressQueryService` — `progressOf(userId, eventId)` -> DTO: NOT_CONFIGURED when no policy; else per-required-lesson {lessonId, title, required, completed, masteryStatus in MASTERED|ASSESSED_BELOW|NOT_ASSESSED, bestKnowledgeScore null-safe}; eventCompleted/eventMastered from user_event_progress rows; unlockedDossiersCount. Reconcile-on-read: if no EVENT_COMPLETED row but all required completed -> run recorder once (idempotent, tx-required method) then re-read — handles pre-V22 data (brief section 9 "co che doi soat").

## Architecture

Evaluation is deterministic function of (policy, attempts state) — keep `EventProgressEvaluator` free of persistence (takes maps) for unit-testability; repositories do the SQL. Recorder = transactional orchestrator: lock -> read -> evaluate -> insert -> fan-out.

## Related Code Files

Create (~14 files, each <200 lines):
- `collection/domain/EventCompletionPolicy.java`, `PolicyStatus.java`, `UserEventProgress.java`, `UserEventProgressId.java`, `EventMilestone.java`, `HistoricalDossier.java`, `DossierType.java`, `DossierStatus.java`, `EventDossier.java`, `EventDossierId.java`, `UserDossierUnlock.java`, `UserDossierUnlockId.java`
- `collection/infrastructure/persistence/{EventCompletionPolicyRepository,UserEventProgressRepository,HistoricalDossierRepository,EventDossierRepository,UserDossierUnlockRepository}.java`
- `collection/application/{EventCompletionPolicyService,EventProgressEvaluator,EventMilestoneRecorder,EventProgressQueryService}.java`
- `collection/api/dto/{EventProgressResponse,RequiredLessonProgress,DossierSummaryResponse,DossierDetailResponse}.java` (DTOs may land here or phase 3)

Verify/reuse (no edit):
- `map/application/MapLocationUnlockQuery.java`
- `learning/application/GradedActivityClassifier.java`
- `collection/infrastructure/persistence/UserEvidenceRepository.java` (insertIgnore pattern)
- `learning/infrastructure/persistence/LessonResultRepository.java` (add finder if needed: best knowledgeScore per lesson via native query — decide in step 4)

## Implementation Steps

1. Write enums + embedded-id classes first (small files).
2. Write entities matching V22 columns exactly; `@JdbcTypeCode(SqlTypes.JSON)` on String jsonb fields per convention.
3. Repos: derived queries + `@Modifying @Query(native)` insertIgnore `ON CONFLICT DO NOTHING`.
4. Add to `LessonResultRepository` (edit existing file): native query `bestKnowledgeScore(userId, lessonId)` = max cast of `result_json->>'knowledgeScore'` over attempts join versions where status='COMPLETED'; plus `completedAttemptsWithResults` list if evaluator needs per-attempt snapshot check. Keep under 40 added lines.
5. `EventCompletionPolicyService`: parse jsonb to `List<UUID>` with ObjectMapper; empty/malformed -> treat as invalid, log, no grant.
6. `EventProgressEvaluator`: implement rules matrix; return record with perLesson statuses for the API.
7. `EventMilestoneRecorder`: advisory lock first statement; then policy -> completion check -> conditional inserts -> fan-out select-insert for PUBLISHED dossiers of that event; batch-fetch newly unlocked ids via `select ... where ... and not exists prior` BEFORE insert vs after — simplest: collect insertIgnore results per dossier (int returned >0 = newly granted). Return set.
8. `EventProgressQueryService`: compose DTO; reconcile: if policy present, no EVENT_COMPLETED row, and completedLessonIds covers all required -> call `recorder.recordCompletion` in same tx (requires this read path be `@Transactional` not readOnly, or a separate txTemplate call — choose txTemplate like LearnerAttemptService.startOrResume idiom).

## Todo List

- [ ] Enums + embedded ids
- [ ] 5 entities aligned with V22
- [ ] 5 repositories incl. insertIgnore natives
- [ ] LessonResultRepository bestKnowledgeScore query
- [ ] EventCompletionPolicyService
- [ ] EventProgressEvaluator (rules matrix)
- [ ] EventMilestoneRecorder (advisory lock + fan-out)
- [ ] EventProgressQueryService (+ reconcile-on-read)
- [ ] DTO records
- [ ] Compile: `mvnw -q compile`

## Success Criteria

- `mvnw compile` clean; Hibernate validate passes in FlywayMigrationIT context.
- Evaluator unit-testable without DB.
- Recorder inserts exactly-once under concurrent invocation (verified phase 5).

## Risk Assessment

- jsonb `required_lesson_ids` may store non-UUID strings -> parse defensively, skip invalid entries with warn log.
- PESSIMISTIC_WRITE on attempt already held by doComplete; advisory lock ordering: always take event lock AFTER attempt row lock to avoid lock-order inversion; document order attempt->(user,event) advisory->milestone insert.
- NOT_ASSESSED vs absent score: bestKnowledgeScore may be null when lesson completed pre-knowledgeScore era -> treat as NOT_ASSESSED for display AND non-qualifying for mastery (brief: missing reliable evidence must not imply mastery).

## Security Considerations

- All queries parameterized; userId only from JWT-derived call sites.
- No learner-facing endpoint in this phase.

## Next Steps

- Phase 3 wires recorder into doComplete and exposes controllers.
