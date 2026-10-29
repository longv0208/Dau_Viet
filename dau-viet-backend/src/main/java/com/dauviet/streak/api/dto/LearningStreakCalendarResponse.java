package com.dauviet.streak.api.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/**
 * GET /api/v1/me/streak/calendar — danh sách ngày đã hoàn thành bài trong
 * khoảng [from, to] (giới hạn tối đa 92 ngày ở service). STREAK-02
 * additive: protectedDates = các ngày được Khiên Bảo Vệ cứu
 * (day_type=SHIELD_PROTECTED) — client render marker 🛡️ khác ngày học 🔥.
 */
public record LearningStreakCalendarResponse(
        LocalDate from,
        LocalDate to,
        String timezone,
        List<LocalDate> days,
        /** Ngày bỏ lỡ được khiên cứu — tập con của days (row ledger vẫn
         *  nằm trong days vì PK (user,study_date)). */
        List<LocalDate> protectedDates,
        Instant serverTime) {
}
