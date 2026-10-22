package com.dauviet.reward.api.dto;

/**
 * Tổng quan thưởng của learner (TASK-0023). MVP chỉ hai loại; client đọc
 * số liệu này để hiển thị EXP / Điểm Lịch sử — không có level/premium.
 */
public record RewardSummaryResponse(
        long exp,
        long historyPoints,
        long lessonsCompleted,
        long itemsOwned
) {
}
