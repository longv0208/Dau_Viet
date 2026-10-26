package com.dauviet.streak.domain;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/**
 * Trạng thái chuỗi ngày học của một learner (V31 / STREAK-01): đúng một
 * dòng/user (PK = user_id), lazy-create khi lần đầu được công nhận ngày học.
 * Đường ghi serialize qua pessimistic lock
 * (UserLearningStreakRepository.findForUpdate) — hai thiết bị complete cùng
 * lúc không thể ghi đè lẫn nhau. row_version chỉ là optimistic lock phụ.
 */
@Entity
@Table(name = "user_learning_streaks")
public class UserLearningStreak {

    @Id
    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    /** Chuỗi ngày liên tiếp hiện tại; về 1 khi bỏ lỡ rồi học lại. */
    @Column(name = "current_streak", nullable = false)
    private int currentStreak;

    /** Kỷ lục chuỗi dài nhất từng đạt — không bao giờ giảm. */
    @Column(name = "longest_streak", nullable = false)
    private int longestStreak;

    /** Ngày VN gần nhất được công nhận; null = chưa từng học. */
    @Column(name = "last_qualified_date")
    private LocalDate lastQualifiedDate;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    public UserLearningStreak() {
    }

    public static UserLearningStreak start(UUID userId, LocalDate qualifiedDate,
                                           Instant now) {
        UserLearningStreak s = new UserLearningStreak();
        s.userId = userId;
        s.currentStreak = 1;
        s.longestStreak = 1;
        s.lastQualifiedDate = qualifiedDate;
        s.createdAt = now;
        s.updatedAt = now;
        return s;
    }

    /**
     * Đẩy chuỗi lên khi được công nhận ngày mới. Quy tắc STREAK-01:
     *   - cùng ngày            → no-op
     *   - ngày kế tiếp (last+1) → current + 1
     *   - ngày cũ hoặc xa hơn  → chuỗi ngắt → current = 1
     * longest luôn = max(longest, current mới).
     */
    public void advanceTo(LocalDate newDate, Instant now) {
        if (newDate == null) return;
        if (lastQualifiedDate != null && newDate.equals(lastQualifiedDate)) {
            return; // đã tính rồi — idempotent
        }
        if (lastQualifiedDate != null
                && newDate.equals(lastQualifiedDate.plusDays(1))) {
            currentStreak += 1;
        } else {
            currentStreak = 1;
        }
        if (currentStreak > longestStreak) {
            longestStreak = currentStreak;
        }
        lastQualifiedDate = newDate;
        updatedAt = now;
    }

    public UUID getUserId() { return userId; }
    public int getCurrentStreak() { return currentStreak; }
    public int getLongestStreak() { return longestStreak; }
    public LocalDate getLastQualifiedDate() { return lastQualifiedDate; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
