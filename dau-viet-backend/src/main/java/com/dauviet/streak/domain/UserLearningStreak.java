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

    /** Số Khiên Bảo Vệ Chuỗi đang tích trữ (0..MAX_SHIELDS, V51). Khi
     * quay lại học sau khi bỏ lỡ đúng 1 ngày, hệ thống tự trừ 1 khiên để
     * giữ chuỗi thay vì reset — xem {@link #advanceTo}. */
    @Column(name = "shield_count", nullable = false)
    private int shieldCount;

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
        s.shieldCount = 0;
        s.createdAt = now;
        s.updatedAt = now;
        return s;
    }

    /** Giới hạn tích trữ Khiên Bảo Vệ (V51): tối đa 3 khiên/user. */
    public static final int MAX_SHIELDS = 3;

    /**
     * Đẩy chuỗi lên khi được công nhận ngày mới. Quy tắc STREAK-02:
     *   - cùng ngày                          → no-op (đã công nhận)
     *   - ngày kế tiếp (last+1)              → current + 1
     *   - cách đúng 1 ngày (last+2) và shieldCount > 0
     *                                        → trừ 1 khiên, current + 1;
     *                                          ngày last+1 được đánh dấu
     *                                          SHIELD_PROTECTED
     *   - còn lại (chưa học / cách 1 ngày mà hết khiên / cách >= 2 ngày)
     *                                        → chuỗi ngắt → current = 1,
     *                                          khiên KHÔNG bị trừ vô ích
     * longest luôn = max(longest, current mới).
     *
     * @return kết quả advance — caller dùng để quyết định grant thưởng
     *         và ghi row SHIELD_PROTECTED vào ledger.
     */
    public AdvanceResult advanceTo(LocalDate newDate, Instant now) {
        if (newDate == null) {
            return AdvanceResult.notRecorded(false, null);
        }
        if (lastQualifiedDate != null && newDate.equals(lastQualifiedDate)) {
            return AdvanceResult.notRecorded(false, null); // idempotent
        }
        boolean shieldConsumed = false;
        LocalDate protectedDate = null;
        if (lastQualifiedDate != null
                && newDate.equals(lastQualifiedDate.plusDays(1))) {
            currentStreak += 1;
        } else if (lastQualifiedDate != null
                && newDate.equals(lastQualifiedDate.plusDays(2))
                && shieldCount > 0) {
            shieldCount -= 1;
            shieldConsumed = true;
            protectedDate = lastQualifiedDate.plusDays(1);
            currentStreak += 1;
        } else {
            currentStreak = 1;
        }
        if (currentStreak > longestStreak) {
            longestStreak = currentStreak;
        }
        lastQualifiedDate = newDate;
        updatedAt = now;
        return new AdvanceResult(true, shieldConsumed, protectedDate);
    }

    /**
     * Kết quả của {@link #advanceTo}: ngày mới có được công nhận không,
     * khiên có tự kích hoạt không và ngày nào được bảo vệ (nếu có).
     */
    public record AdvanceResult(
            boolean dayRecorded,
            boolean shieldConsumed,
            LocalDate protectedDate) {
        static AdvanceResult notRecorded(boolean shieldConsumed,
                                         LocalDate protectedDate) {
            return new AdvanceResult(false, shieldConsumed, protectedDate);
        }
    }

    /** Mua thêm một khiên — caller phải kiểm tra {@link #MAX_SHIELDS}
     * và trừ Điểm Sử Ký trước khi gọi (thứ tự: check → debit → increment
     * trong cùng transaction; debit throw thì rollback cả increment). */
    public void addShield(Instant now) {
        if (shieldCount >= MAX_SHIELDS) {
            throw new IllegalStateException(
                    "shield capacity reached for user " + userId);
        }
        shieldCount += 1;
        updatedAt = now;
    }

    public UUID getUserId() { return userId; }
    public int getCurrentStreak() { return currentStreak; }
    public int getLongestStreak() { return longestStreak; }
    public LocalDate getLastQualifiedDate() { return lastQualifiedDate; }
    public int getShieldCount() { return shieldCount; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
