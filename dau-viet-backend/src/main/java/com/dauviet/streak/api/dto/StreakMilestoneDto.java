package com.dauviet.streak.api.dto;

/**
 * Một mốc thưởng chuỗi ngày học (STREAK-02, V51) — bảng tĩnh do server
 * trả để client không hard-code 3/7/14/30 hay số lượng thưởng.
 */
public record StreakMilestoneDto(
        /** current_streak đạt mốc này thì bonus kích hoạt. */
        int day,
        /** EXP bonus CỘNG THÊM trên thưởng duy trì tại mốc. */
        long bonusExp,
        /** Điểm Sử Ký bonus CỘNG THÊM trên thưởng duy trì tại mốc. */
        long bonusPoints) {
}
