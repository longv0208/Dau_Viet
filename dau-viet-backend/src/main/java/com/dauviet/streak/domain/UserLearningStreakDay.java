package com.dauviet.streak.domain;

import java.io.Serializable;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Objects;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;

/**
 * Ledger kiểm toán từng ngày được công nhận (V31 / STREAK-01). PK tổ hợp
 * (user_id, study_date) — UNIQUE constraint chống 2 tx concurrent tạo trùng
 * một ngày. Lưu lesson + attempt đầu tiên kích hoạt ngày đó; các hoàn thành
 * sau cùng ngày không cập nhật row này (INSERT ON CONFLICT DO NOTHING).
 */
@Entity
@Table(name = "user_learning_streak_days")
@IdClass(UserLearningStreakDay.PK.class)
public class UserLearningStreakDay {

    @Id
    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Id
    @Column(name = "study_date", nullable = false, updatable = false)
    private LocalDate studyDate;

    @Column(name = "lesson_id", nullable = false, updatable = false)
    private UUID lessonId;

    @Column(name = "learner_attempt_id", nullable = false, updatable = false)
    private UUID learnerAttemptId;

    /** completed_at của attempt đầu tiên trong ngày (UTC). */
    @Column(name = "completed_at", nullable = false, updatable = false)
    private Instant completedAt;

    /** STUDY = ngày học thực; SHIELD_PROTECTED = ngày bỏ lỡ được khiên cứu
     * (V51) — lesson_id/learner_attempt_id trỏ về attempt của ngày học
     * sau đã kích hoạt auto-consume. */
    @Column(name = "day_type", nullable = false, updatable = false)
    private String dayType;

    /** EXP thưởng chuỗi đã grant cho ngày này (V51); 0 với ngày khiên. */
    @Column(name = "reward_exp", nullable = false, updatable = false)
    private int rewardExp;

    /** Điểm Sử Ký thưởng chuỗi đã grant cho ngày này (V51). */
    @Column(name = "reward_points", nullable = false, updatable = false)
    private int rewardPoints;

    /** Mốc chuỗi đạt được ngày này (3/7/14/30) nếu có; null = không mốc. */
    @Column(name = "milestone_day", updatable = false)
    private Integer milestoneDay;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public static final String DAY_TYPE_STUDY = "STUDY";
    public static final String DAY_TYPE_SHIELD_PROTECTED = "SHIELD_PROTECTED";

    public UserLearningStreakDay() {
    }

    public static UserLearningStreakDay of(UUID userId, LocalDate studyDate,
                                           UUID lessonId, UUID learnerAttemptId,
                                           Instant completedAt, Instant now) {
        return of(userId, studyDate, lessonId, learnerAttemptId,
                completedAt, DAY_TYPE_STUDY, 0, 0, null, now);
    }

    public static UserLearningStreakDay of(UUID userId, LocalDate studyDate,
                                           UUID lessonId, UUID learnerAttemptId,
                                           Instant completedAt, String dayType,
                                           int rewardExp, int rewardPoints,
                                           Integer milestoneDay, Instant now) {
        UserLearningStreakDay d = new UserLearningStreakDay();
        d.userId = userId;
        d.studyDate = studyDate;
        d.lessonId = lessonId;
        d.learnerAttemptId = learnerAttemptId;
        d.completedAt = completedAt;
        d.dayType = dayType;
        d.rewardExp = rewardExp;
        d.rewardPoints = rewardPoints;
        d.milestoneDay = milestoneDay;
        d.createdAt = now;
        return d;
    }

    public UUID getUserId() { return userId; }
    public LocalDate getStudyDate() { return studyDate; }
    public UUID getLessonId() { return lessonId; }
    public UUID getLearnerAttemptId() { return learnerAttemptId; }
    public Instant getCompletedAt() { return completedAt; }
    public String getDayType() { return dayType; }
    public int getRewardExp() { return rewardExp; }
    public int getRewardPoints() { return rewardPoints; }
    public Integer getMilestoneDay() { return milestoneDay; }
    public Instant getCreatedAt() { return createdAt; }
    /** Composite PK — (user_id, study_date). */
    public static class PK implements Serializable {
        private UUID userId;
        private LocalDate studyDate;

        public PK() {
        }

        public PK(UUID userId, LocalDate studyDate) {
            this.userId = userId;
            this.studyDate = studyDate;
        }

        @Override public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof PK)) return false;
            PK pk = (PK) o;
            return Objects.equals(userId, pk.userId)
                    && Objects.equals(studyDate, pk.studyDate);
        }

        @Override public int hashCode() {
            return Objects.hash(userId, studyDate);
        }
    }
}
