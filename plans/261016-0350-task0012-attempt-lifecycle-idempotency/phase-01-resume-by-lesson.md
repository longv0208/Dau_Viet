# Phase 01 — Resume by Lesson (cross-version)

## Context

- TASK-0011 known limitation: `startOrResume` looks up
  `findByUserIdAndLessonVersionIdAndStatus(userId, currentVersionId, IN_PROGRESS)`.
  If a learner has an in-progress attempt on v1 and the admin republishes → v2,
  a fresh POST /attempts creates a SECOND attempt on v2 (allowed by
  `ux_attempt_active_user_version` since it keys on `lesson_version_id`).
- Brief §2: "resume must work after restart/logout/republish. Resolve the existing
  version-specific resume limitation without breaking version pinning" and
  "Do not automatically replace an existing in-progress attempt with a newer
  LessonVersion".

## Decision

- Resume scope = **(user, lesson)**, not (user, version).
- Implementation: JPQL join `LearnerAttempt` → `LessonVersion` on
  `lesson_version_id = lv.id` where `lv.lessonId = :lessonId`. No schema change
  (no `lesson_id` denorm column — join is O(1) under PK, both tables indexed).
- After COMPLETED attempt on v1, POST /attempts starts a NEW attempt pinned to
  `current_version_id` (v2 if republished) — repeats allowed, brief confirms.
- One active attempt per user+lesson enforced in service (see below); DB index
  already covers the common same-version case.

## Repository changes

`LearnerAttemptRepository` — add:

```java
@Query("select a from LearnerAttempt a join LessonVersion v "
     + "on a.lessonVersionId = v.id "
     + "where a.userId = :userId and v.lessonId = :lessonId "
     + "and a.status = :status")
Optional<LearnerAttempt> findActiveByUserAndLesson(
        @Param("userId") UUID userId,
        @Param("lessonId") UUID lessonId,
        @Param("status") LearnerAttemptStatus status);
```

For history listing (Phase 04):

```java
@Query("select a from LearnerAttempt a join LessonVersion v "
     + "on a.lessonVersionId = v.id where a.userId = :userId "
     + "order by a.lastActiveAt desc")
Page<LearnerAttempt> findByUser(@Param("userId") UUID userId, Pageable p);

@Query("select a from LearnerAttempt a join LessonVersion v "
     + "on a.lessonVersionId = v.id where a.userId = :userId "
     + "and a.status = :status order by a.lastActiveAt desc")
Page<LearnerAttempt> findByUserAndStatus(
        @Param("userId") UUID userId,
        @Param("status") LearnerAttemptStatus status, Pageable p);
```

(Alternatively add `lessonId` to `LearnerAttempt` entity via `@Formula` or
secondary join — keep simple: JPQL join only.)

## Service change (`LearnerAttemptService.startOrResume`)

```
1. loadPublished(lessonId) — unchanged (PUBLISHED + current_version_id).
2. existing = attempts.findActiveByUserAndLesson(userId, lessonId, IN_PROGRESS)
   → if present: return resumed=true, attempt fields; pinned version stays the
     attempt's own lessonVersionId (may be < current).
3. Otherwise create new attempt pinned to lesson.currentVersionId — unchanged.
```

Race note: two concurrent `POST /lessons/{id}/attempts` from the same user when
no attempt exists → both pass check, both insert. Partial unique index stops the
same-version duplicate (second gets `DataIntegrityViolationException` → 500
currently). For MVP: **catch + translate to existing-attempt resume** — wrap
`attempts.save` in try/catch on `DataIntegrityViolationException`, reload via
`findActiveByUserAndLesson`, return it (idempotent-start semantics). Cross-version
concurrent start remains theoretically possible only if republish happens mid-race
— accepted residual, documented.

## Tests (phase 05 runs them; authored here)

- `ResumeAcrossRepublishIT.attemptOnV1_resumedAfterV2Publish`: start on v1,
  republish lesson (v2), POST /attempts → `resumed=true`, same attemptId,
  `lessonVersionId` still v1.
- `ResumeAcrossRepublishIT.completedAttempt_allowsNewAttemptOnV2`: complete on v1
  (phase-02 enables), republish v2, POST /attempts → `resumed=false`, new
  attemptId, `lessonVersionId` = v2.
- `LearnerAttemptApiIT.concurrentStart_singleAttempt` (extend or new IT): 2
  threads POST /attempts simultaneously → both 200, one `resumed=true`,
  `count(learner_attempts where user) = 1`.

## Files

- Modify `LearnerAttemptRepository` (add 3 queries)
- Modify `LearnerAttemptService.startOrResume` (~15 lines)
- New `ResumeAcrossRepublishIT` test

## Acceptance criteria (task.json AC mapping)

- AC: "Resume works across republish — an in-progress attempt on a superseded
  version resumes by lesson, keeping its pinned version."
- AC: "Starting after completion on an old version creates a fresh attempt on
  current version."
