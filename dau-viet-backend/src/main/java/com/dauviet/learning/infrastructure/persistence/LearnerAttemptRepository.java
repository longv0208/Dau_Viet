package com.dauviet.learning.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.dauviet.learning.domain.LearnerAttempt;

@Repository
public interface LearnerAttemptRepository extends JpaRepository<LearnerAttempt, UUID> {

    /** The single active attempt for (user, version) — ux_attempt_active_user_version. */
    Optional<LearnerAttempt> findByUserIdAndLessonVersionIdAndStatus(
            UUID userId, UUID lessonVersionId,
            com.dauviet.learning.domain.LearnerAttemptStatus status);

    /**
     * The learner's IN_PROGRESS attempt for a LESSON, whatever version it is
     * pinned to — resume must survive republish (TASK-0012): an in-flight
     * attempt on v1 is resumed, never replaced by a v2 attempt.
     */
    @Query("select a from LearnerAttempt a, LessonVersion v "
         + "where a.lessonVersionId = v.id and v.lessonId = :lessonId "
         + "and a.userId = :userId and a.status = 'IN_PROGRESS'")
    Optional<LearnerAttempt> findInProgressByUserIdAndLessonId(
            @Param("userId") UUID userId, @Param("lessonId") UUID lessonId);

    /** All attempts of a learner for one lesson, newest activity first. */
    @Query("select a from LearnerAttempt a, LessonVersion v "
         + "where a.lessonVersionId = v.id and v.lessonId = :lessonId "
         + "and a.userId = :userId order by a.lastActiveAt desc")
    List<LearnerAttempt> findByUserIdAndLessonIdOrderByLastActiveAtDesc(
            @Param("userId") UUID userId, @Param("lessonId") UUID lessonId);

    /** Paged attempt history for one learner, newest activity first. */
    org.springframework.data.domain.Page<LearnerAttempt>
            findByUserIdOrderByLastActiveAtDesc(
                    UUID userId, org.springframework.data.domain.Pageable pageable);

    /** Paged attempt history filtered by status. */
    org.springframework.data.domain.Page<LearnerAttempt>
            findByUserIdAndStatusOrderByLastActiveAtDesc(
                    UUID userId,
                    com.dauviet.learning.domain.LearnerAttemptStatus status,
                    org.springframework.data.domain.Pageable pageable);

    /** All IN_PROGRESS attempts of a learner — bounded by the one-per-lesson policy. */
    List<LearnerAttempt> findByUserIdAndStatusOrderByLastActiveAtDesc(
            UUID userId, com.dauviet.learning.domain.LearnerAttemptStatus status);

    long countByUserIdAndStatus(UUID userId,
            com.dauviet.learning.domain.LearnerAttemptStatus status);

    /** Pessimistic write lock — serializes concurrent submits on one attempt. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select a from LearnerAttempt a where a.id = :id")
    Optional<LearnerAttempt> findForUpdate(@Param("id") UUID id);
}
