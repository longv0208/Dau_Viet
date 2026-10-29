package com.dauviet.streak.api.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/**
 * Trạng thái chuỗi ngày học trả cho GET /api/v1/me/streak (STREAK-01 +
 * STREAK-02 additive — V51).
 *
 * <p>streakAlive phân biệt hai trạng thái quan trọng:
 *   - true  → chuỗi còn sống (đã học hôm nay HOẶC hôm qua — còn cơ hội giữ)
 *   - false → chuỗi đã ngắt hoặc chưa từng học
 * Client dùng cờ này để hiển thị "giữ chuỗi" thay vì 0 quá sớm.
 *
 * <p>STREAK-02 additive: shieldCount/maxShields/shieldCostPoints cho thẻ
 * Khiên Bảo Vệ; atRiskToday (học hôm qua, chưa học hôm nay) +
 * shieldWillProtectToday cho cảnh báo đứt chuỗi; milestones là bảng
 * thưởng mốc tĩnh để client render card tiến độ không hard-code.
 */
public record LearningStreakResponse(
        int currentStreak,
        int longestStreak,
        boolean completedToday,
        boolean streakAlive,
        LocalDate lastQualifiedDate,
        LocalDate today,
        String timezone,
        Instant serverTime,
        /** Số Khiên Bảo Vệ đang tích trữ (0..maxShields). */
        int shieldCount,
        /** Giới hạn khiên — 3 ở V51. */
        int maxShields,
        /** Giá đổi một khiên — Điểm Sử Ký. */
        long shieldCostPoints,
        /** Chuỗi có nguy cơ đứt nếu hôm nay không học (last == today-1). */
        boolean atRiskToday,
        /** Khiên sẽ tự cứu nếu hôm nay bỏ lỡ đúng 1 ngày. */
        boolean shieldWillProtectToday,
        /** Bảng mốc thưởng 3/7/14/30 — tĩnh phía server. */
        List<StreakMilestoneDto> milestones) {
}
