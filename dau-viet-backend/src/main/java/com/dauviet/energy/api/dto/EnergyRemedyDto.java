package com.dauviet.energy.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Một vật phẩm Viện Thái Y trong payload GET /me/energy (GAME-07).
 *
 * <p>`eligible` là quyết định server — client chỉ render; KHÔNG tự suy
 * từ energy/balance phía UI để tránh lệch khi policy thay đổi. Khi
 * `eligible=false`, `blockReasons` chứa các lý do máy-đọc:
 * "ENERGY_FULL" / "REFILL_RATE_LIMITED" / "INSUFFICIENT_FUNDS".
 *
 * <p>`effectiveEnergyGain` là số Thể lực THỰC sẽ cộng nếu refill ngay
 * (đã clamp trần max — cùng giá remedy nhưng gain nhỏ hơn khi gần đầy).
 * `cooldownEndsAt` null khi không cooldown hoặc đã hết.
 */
public record EnergyRemedyDto(
        UUID id,
        String code,
        String title,
        String description,
        String rarity,
        String iconKey,
        UUID assetId,
        int energyGain,
        long pointsCost,
        int cooldownSeconds,
        boolean eligible,
        int effectiveEnergyGain,
        Instant cooldownEndsAt,
        List<String> blockReasons) {
}
