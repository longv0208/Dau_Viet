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
 * <p>`enabled` là feature flag rollout an toàn (FIX 3): true = áp
 * penalty + zero-energy gate; false = chỉ theo dõi trạng thái,
 * submit không trừ/không chặn. MẶC ĐỊNH false — production/dev an toàn
 * cho tới khi GAME-03 (Flutter xử lý ENERGY_DEPLETED + đồng hồ đếm)
 * tích hợp xong; bật qua `DAUVIET_ENERGY_ENABLED=true`/profile env.
 * Bật/tắt KHÔNG reset dữ liệu energy_transactions/user_energy cũ.
 */
@ConfigurationProperties(prefix = "dauviet.energy")
public record EnergyProperties(
        @DefaultValue("false") boolean enabled,
        @DefaultValue("100") int maxEnergy,
        @DefaultValue("10") int incorrectPenalty,
        @DefaultValue("5") int recoveryAmount,
        @DefaultValue("15m") Duration recoveryInterval) {

    /** Hard cap schema V21: CHECK(current_energy BETWEEN 0 AND 100). */
    public static final int SCHEMA_MAX_ENERGY = 100;

    @PostConstruct
    void validate() {
        if (maxEnergy <= 0) {
            throw new IllegalStateException(
                    "dauviet.energy.max-energy must be > 0, got " + maxEnergy);
        }
        if (maxEnergy > SCHEMA_MAX_ENERGY) {
            // FIX 4: khớp CHECK constraint của V21 — cấu hình max-energy lớn
            // hơn 100 sẽ nổ ngay tại insert user_energy nếu không chặn ở đây.
            throw new IllegalStateException(
                    "dauviet.energy.max-energy (" + maxEnergy
                            + ") exceeds schema CHECK cap "
                            + SCHEMA_MAX_ENERGY);
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
        if (recoveryInterval.minusSeconds(1).isNegative()) {
            // FIX 4: interval < 1s làm Duration.dividedBy trong recovery
            // trả kết quả sai/chia gần 0 — cấu hình nửa giây vô nghĩa.
            throw new IllegalStateException(
                    "dauviet.energy.recovery-interval must be >= 1s, got "
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
