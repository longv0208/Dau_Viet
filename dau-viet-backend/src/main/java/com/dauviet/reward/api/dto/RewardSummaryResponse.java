package com.dauviet.reward.api.dto;

/**
 * Tổng quan thưởng của learner (TASK-0023, ISLAND-01). Level được backend tính
 * từ EXP tích lũy — không hard-code bảng ngưỡng trong Flutter; client đọc
 * trường này để hiển thị cấp tài khoản chính thức.
 */
public record RewardSummaryResponse(
        long exp,
        long historyPoints,
        long lessonsCompleted,
        long itemsOwned,
        /** Level tài khoản hiện tại (tính từ EXP theo cấu hình backend). */
        int level
) {
}
