package com.dauviet.streak.api.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/**
 * GET /api/v1/me/streak/calendar — danh sách ngày đã hoàn thành bài trong
 * khoảng [from, to] (giới hạn tối đa 92 ngày ở service). Mỗi ngày có kèm
 * attempt đầu tiên kích hoạt để client audit nếu cần.
 */
public record LearningStreakCalendarResponse(
        LocalDate from,
        LocalDate to,
        String timezone,
        List<LocalDate> days,
        Instant serverTime) {
}
