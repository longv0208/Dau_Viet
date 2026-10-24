package com.dauviet.energy.api.dto;

import java.time.Instant;

/**
 * Contract GET /api/v1/me/energy (GAME-02 §5.2): mọi thời gian do server
 * tính — client chỉ render, không tự suy ra trạng thái. `nextRecoveryAt`
 * null khi đã đầy (không có chu kỳ hồi đang chờ). `canSubmitGraded` phản
 * ánh gate hiện tại (kể cả khi feature flag tắt → luôn true để client không
 * khóa nhầm UI).
 */
public record EnergyStateResponse(
        int current,
        int max,
        int recoveryAmount,
        long recoveryIntervalSeconds,
        Instant nextRecoveryAt,
        Instant serverTime,
        boolean canSubmitGraded) {
}
