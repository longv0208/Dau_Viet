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

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public UserLearningStreakDay() {
    }

    public static UserLearningStreakDay of(UUID userId, LocalDate studyDate,
                                           UUID lessonId, UUID learnerAttemptId,
                                           Instant completedAt, Instant now) {
        UserLearningStreakDay d = new UserLearningStreakDay();
        d.userId = userId;
        d.studyDate = studyDate;
        d.lessonId = lessonId;
        d.learnerAttemptId = learnerAttemptId;
        d.completedAt = completedAt;
        d.createdAt = now;
        return d;
    }

    public UUID getUserId() { return userId; }
    public LocalDate getStudyDate() { return studyDate; }
    public UUID getLessonId() { return lessonId; }
    public UUID getLearnerAttemptId() { return learnerAttemptId; }
    public Instant getCompletedAt() { return completedAt; }
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
