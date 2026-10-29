package com.dauviet.energy.api.dto;

import java.time.Instant;
import java.util.List;

/**
 * Contract GET /api/v1/me/energy (GAME-02 §5.2 + GAME-07 Issue #28):
 * mọi thời gian do server tính — client chỉ render, không tự suy ra
 * trạng thái. `nextRecoveryAt` null khi đã đầy (không có chu kỳ hồi đang
 * chờ). `canSubmitGraded` phản ánh gate hiện tại (kể cả khi feature flag
 * tắt → luôn true để client không khóa nhầm UI).
 *
 * <p>GAME-07: thêm `pointsBalance` (Điểm Sử Ký từ wallet ledger — server
 * quyết) và `remedies` (catalog Viện Thái Y với eligible + blockReasons
 * do server quyết — client KHÔNG tự đánh giá từ energy/balance).
 */
public record EnergyStateResponse(
        int current,
        int max,
        int recoveryAmount,
        long recoveryIntervalSeconds,
        Instant nextRecoveryAt,
        Instant serverTime,
        boolean canSubmitGraded,
        long pointsBalance,
        List<EnergyRemedyDto> remedies) {
}
