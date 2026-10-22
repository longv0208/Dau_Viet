package com.dauviet.learning.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import com.dauviet.learning.domain.LessonResult;

@Repository
public interface LessonResultRepository extends JpaRepository<LessonResult, UUID> {

    Optional<LessonResult> findByLearnerAttemptId(UUID learnerAttemptId);

    /**
     * TASK-0023 reward backfill: (attempt_id, user_id, lesson_id) của mọi
     * attempt COMPLETED theo thứ tự thời gian — service lọc lần hoàn
     * thành đầu tiên mỗi (user, lesson) rồi grant qua cause_key idempotent.
     * Native query vì cần join learner_attempts + lesson_versions mà
     * LessonResult không giữ quan hệ entity.
     */
    @Query(value = """
            SELECT a.id, a.user_id, v.lesson_id
            FROM learner_attempts a
            JOIN lesson_versions v ON v.id = a.lesson_version_id
            WHERE a.status = 'COMPLETED'
            ORDER BY a.completed_at ASC
            """, nativeQuery = true)
    List<Object[]> findCompletedAttemptsForBackfill();
}
