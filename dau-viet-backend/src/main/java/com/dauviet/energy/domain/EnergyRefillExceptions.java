package com.dauviet.energy.domain;

import java.time.Instant;
import java.util.Map;

/**
 * Domain exceptions cho luồng refill Viện Thái Y (GAME-07) — map sang
 * ApiError code qua GlobalExceptionHandler, giống
 * {@link com.dauviet.island.domain.IslandExceptions}.
 */
public final class EnergyRefillExceptions {

    private EnergyRefillExceptions() {
    }

    /** 404 — remedy code không tồn tại hoặc đang inactive. */
    public static class RemedyNotFoundException extends RuntimeException {
        private final String code;

        public RemedyNotFoundException(String code) {
            super("remedy not found or inactive: " + code);
            this.code = code;
        }

        public String getCode() { return code; }
    }

    /**
     * 422 — learner không đủ điều kiện refill. `reason` chi tiết:
     * "ENERGY_FULL" (đang 100/100) hoặc lý do khác nếu mở rộng sau.
     */
    public static class RefillNotEligibleException extends RuntimeException {
        private final String reason;
        private final int currentEnergy;
        private final int maxEnergy;

        public RefillNotEligibleException(String reason,
                                          int currentEnergy,
                                          int maxEnergy) {
            super("refill not eligible: " + reason);
            this.reason = reason;
            this.currentEnergy = currentEnergy;
            this.maxEnergy = maxEnergy;
        }

        public String getReason() { return reason; }
        public Map<String, Object> details() {
            return Map.of(
                    "reason", reason,
                    "currentEnergy", currentEnergy,
                    "maxEnergy", maxEnergy);
        }
    }

    /**
     * 409 — remedy đang trong cooldown. details có lastRefillAt +
     * nextEligibleAt + serverTime để client hiển thị countdown chính xác
     * (không tự tính).
     */
    public static class RefillRateLimitedException extends RuntimeException {
        private final String remedyCode;
        private final Instant lastRefillAt;
        private final Instant nextEligibleAt;
        private final Instant serverTime;

        public RefillRateLimitedException(String remedyCode,
                                          Instant lastRefillAt,
                                          Instant nextEligibleAt,
                                          Instant serverTime) {
            super("remedy is on cooldown: " + remedyCode);
            this.remedyCode = remedyCode;
            this.lastRefillAt = lastRefillAt;
            this.nextEligibleAt = nextEligibleAt;
            this.serverTime = serverTime;
        }

        public String getRemedyCode() { return remedyCode; }
        public Map<String, Object> details() {
            return Map.of(
                    "remedyCode", remedyCode,
                    "lastRefillAt", lastRefillAt,
                    "nextEligibleAt", nextEligibleAt,
                    "serverTime", serverTime);
        }
    }
}
