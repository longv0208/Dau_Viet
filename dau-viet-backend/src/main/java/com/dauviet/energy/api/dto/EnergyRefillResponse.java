package com.dauviet.energy.api.dto;

import java.time.Instant;

/**
 * Response POST /api/v1/me/energy/refills — trả snapshot đầy đủ để client
 * applySnapshot() ngay mà không cần GET /me/energy lại.
 *
 * <p>`energy` là EnergyStateResponse mới (đã gồm remedies + pointsBalance
 * sau khi trừ) — client cập nhật ví + thanh Thể lực một lần.
 * `nextEligibleAt` = thời điểm remedy này hết cooldown (null nếu không
 * cooldown). `pointsSpent` = remedy.pointsCost thực trừ (0 cho gói free).
 */
public record EnergyRefillResponse(
        EnergyStateResponse energy,
        String remedyCode,
        int energyCredited,
        long pointsSpent,
        long walletBalance,
        Instant refillAt,
        Instant nextEligibleAt,
        Instant serverTime) {
}
