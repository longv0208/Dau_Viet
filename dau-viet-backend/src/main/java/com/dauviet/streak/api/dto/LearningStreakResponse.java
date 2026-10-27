package com.dauviet.streak.api.dto;

import java.time.Instant;
import java.time.LocalDate;

/**
 * Trạng thái chuỗi ngày học trả cho GET /api/v1/me/streak (STREAK-01).
 *
 * <p>streakAlive phân biệt hai trạng thái quan trọng:
 *   - true  → chuỗi còn sống (đã học hôm nay HOẶC hôm qua — còn cơ hội giữ)
 *   - false → chuỗi đã ngắt hoặc chưa từng học
 * Client dùng cờ này để hiển thị "giữ chuỗi" thay vì 0 quá sớm.
 */
public record LearningStreakResponse(
        int currentStreak,
        int longestStreak,
        boolean completedToday,
        boolean streakAlive,
        LocalDate lastQualifiedDate,
        LocalDate today,
        String timezone,
        Instant serverTime) {
}
