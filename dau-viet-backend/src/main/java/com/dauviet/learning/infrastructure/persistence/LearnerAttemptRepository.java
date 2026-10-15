package com.dauviet.learning.infrastructure.persistence;

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

    /** Pessimistic write lock — serializes concurrent submits on one attempt. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select a from LearnerAttempt a where a.id = :id")
    Optional<LearnerAttempt> findForUpdate(@Param("id") UUID id);
}
