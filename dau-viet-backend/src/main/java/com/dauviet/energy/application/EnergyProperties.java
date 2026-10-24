package com.dauviet.energy.application;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

import jakarta.annotation.PostConstruct;

/**
 * Chính sách Thể lực tập trung (GAME-02, ENGY-01..10): MỌI công thức số đọc
 * từ đây — không hard-code ở service/handler. Validate fail-fast khi khởi
 * động: cấu hình sai thì app không lên, tránh lúc chạy mới nổ CHECK 0-100
 * của DB.
 *
 * <p>`enabled` là feature flag rollout an toàn (§12 brief): true = áp
 * penalty + zero-energy gate (mặc định); false = chỉ theo dõi trạng thái,
 * submit không trừ/không chặn — dùng khi cần triển khai lệch phiên bản
 * mobile (GAME-03 chưa xử lý ENERGY_DEPLETED).
 */
@ConfigurationProperties(prefix = "dauviet.energy")
public record EnergyProperties(
        @DefaultValue("true") boolean enabled,
        @DefaultValue("100") int maxEnergy,
        @DefaultValue("10") int incorrectPenalty,
        @DefaultValue("5") int recoveryAmount,
        @DefaultValue("15m") Duration recoveryInterval) {

    @PostConstruct
    void validate() {
        if (maxEnergy <= 0) {
            throw new IllegalStateException(
                    "dauviet.energy.max-energy must be > 0, got " + maxEnergy);
        }
        if (incorrectPenalty <= 0) {
            throw new IllegalStateException(
                    "dauviet.energy.incorrect-penalty must be > 0, got "
                            + incorrectPenalty);
        }
        if (recoveryAmount <= 0) {
            throw new IllegalStateException(
                    "dauviet.energy.recovery-amount must be > 0, got "
                            + recoveryAmount);
        }
        if (recoveryInterval == null || recoveryInterval.isZero()
                || recoveryInterval.isNegative()) {
            throw new IllegalStateException(
                    "dauviet.energy.recovery-interval must be positive, got "
                            + recoveryInterval);
        }
        if (incorrectPenalty > maxEnergy) {
            throw new IllegalStateException(
                    "dauviet.energy.incorrect-penalty (" + incorrectPenalty
                            + ") exceeds max-energy (" + maxEnergy + ")");
        }
        if (recoveryAmount > maxEnergy) {
            throw new IllegalStateException(
                    "dauviet.energy.recovery-amount (" + recoveryAmount
                            + ") exceeds max-energy (" + maxEnergy + ")");
        }
    }
}
