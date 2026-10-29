package com.dauviet.streak.api.dto;

import java.time.Instant;

/**
 * Response của POST /api/v1/me/streak/shields (STREAK-02, V51) — kết quả
 * đổi 20 Điểm Sử Ký lấy 1 Khiên Bảo Vệ Chuỗi. Trả cả số dư ví sau debit
 * để client cập nhật pill Điểm Sử Ký mà không cần refetch.
 */
public record StreakShieldPurchaseResponse(
        /** Số khiên sau khi mua (1..maxShields). */
        int shieldCount,
        /** Giới hạn tích trữ — luôn 3 ở V51. */
        int maxShields,
        /** Giá đã trả — Điểm Sử Ký. */
        long costPoints,
        /** Số dư ví sau debit — client render lại pill ngay. */
        long balanceAfter,
        /** Đồng hồ server lúc ghi — mốc freshness cho client. */
        Instant serverTime) {
}
