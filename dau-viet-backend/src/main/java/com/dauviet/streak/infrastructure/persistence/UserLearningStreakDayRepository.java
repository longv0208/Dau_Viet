package com.dauviet.streak.infrastructure.persistence;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.streak.domain.UserLearningStreakDay;

/**
 * Ledger user_learning_streak_days (V31). PK (user_id, study_date) là lớp
 * chống trùng cuối cùng — hai tx concurrent complete cùng ngày chỉ tạo đúng
 * một row. Mọi insert đi qua {@link #insertIgnore}.
 */
public interface UserLearningStreakDayRepository
        extends JpaRepository<UserLearningStreakDay, UserLearningStreakDay.PK> {

    /**
     * Ghi nhận một ngày học; ngày đã có → bỏ qua (giữ attempt đầu tiên).
     * @return 1 nếu vừa insert, 0 nếu đã tồn tại.
     */
    @Modifying
    @Query(value = """
            INSERT INTO user_learning_streak_days
                (user_id, study_date, lesson_id, learner_attempt_id,
                 completed_at, created_at)
            VALUES (:userId, :studyDate, :lessonId, :attemptId,
                    :completedAt, :now)
            ON CONFLICT (user_id, study_date) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("studyDate") LocalDate studyDate,
                     @Param("lessonId") UUID lessonId,
                     @Param("attemptId") UUID attemptId,
                     @Param("completedAt") java.time.Instant completedAt,
                     @Param("now") java.time.Instant now);

    /** Lịch sử ngày đã học trong khoảng [from, to] — cho GET /me/streak/calendar. */
    @Query("SELECT d.studyDate FROM UserLearningStreakDay d "
            + "WHERE d.userId = :userId "
            + "AND d.studyDate BETWEEN :from AND :to "
            + "ORDER BY d.studyDate ASC")
    List<LocalDate> findDatesBetween(@Param("userId") UUID userId,
                                     @Param("from") LocalDate from,
                                     @Param("to") LocalDate to);
}
