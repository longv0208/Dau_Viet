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
     * Ghi nhận một ngày; ngày đã có → bỏ qua (giữ attempt đầu tiên).
     * day_type/reward_* do caller quyết định theo kết quả advanceTo —
     * ngày SHIELD_PROTECTED mang reward 0 và trỏ attempt của ngày sau.
     * @return 1 nếu vừa insert, 0 nếu đã tồn tại.
     */
    @Modifying
    @Query(value = """
            INSERT INTO user_learning_streak_days
                (user_id, study_date, lesson_id, learner_attempt_id,
                 completed_at, day_type, reward_exp, reward_points,
                 milestone_day, created_at)
            VALUES (:userId, :studyDate, :lessonId, :attemptId,
                    :completedAt, :dayType, :rewardExp, :rewardPoints,
                    :milestoneDay, :now)
            ON CONFLICT (user_id, study_date) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("studyDate") LocalDate studyDate,
                     @Param("lessonId") UUID lessonId,
                     @Param("attemptId") UUID attemptId,
                     @Param("completedAt") java.time.Instant completedAt,
                     @Param("dayType") String dayType,
                     @Param("rewardExp") int rewardExp,
                     @Param("rewardPoints") int rewardPoints,
                     @Param("milestoneDay") Integer milestoneDay,
                     @Param("now") java.time.Instant now);

    /** Lịch sử ngày đã học trong khoảng [from, to] — cho GET /me/streak/calendar. */
    @Query("SELECT d.studyDate FROM UserLearningStreakDay d "
            + "WHERE d.userId = :userId "
            + "AND d.studyDate BETWEEN :from AND :to "
            + "ORDER BY d.studyDate ASC")
    List<LocalDate> findDatesBetween(@Param("userId") UUID userId,
                                     @Param("from") LocalDate from,
                                     @Param("to") LocalDate to);

    /** Các ngày được Khiên Bảo Vệ cứu trong [from, to] — cho calendar
     * hiển thị marker 🛡️ khác với ngày học thực 🔥 (V51). */
    @Query("SELECT d.studyDate FROM UserLearningStreakDay d "
            + "WHERE d.userId = :userId "
            + "AND d.dayType = 'SHIELD_PROTECTED' "
            + "AND d.studyDate BETWEEN :from AND :to "
            + "ORDER BY d.studyDate ASC")
    List<LocalDate> findProtectedDatesBetween(@Param("userId") UUID userId,
                                              @Param("from") LocalDate from,
                                              @Param("to") LocalDate to);

    /**
     * Đắp reward/milestone vào row vừa insert trong cùng tx (V51) — chỉ
     * chạy khi caller biết chắc row là của tx này (insertIgnore trả 1).
     * Không dùng cho replay: ngày đã có sẽ không tới nhánh này.
     */
    @Modifying
    @Query(value = """
            UPDATE user_learning_streak_days
               SET reward_exp = :rewardExp,
                   reward_points = :rewardPoints,
                   milestone_day = :milestoneDay
             WHERE user_id = :userId AND study_date = :studyDate
            """, nativeQuery = true)
    int updateReward(@Param("userId") UUID userId,
                     @Param("studyDate") LocalDate studyDate,
                     @Param("rewardExp") int rewardExp,
                     @Param("rewardPoints") int rewardPoints,
                     @Param("milestoneDay") Integer milestoneDay);
}
