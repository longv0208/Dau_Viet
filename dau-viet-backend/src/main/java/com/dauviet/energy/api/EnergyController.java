package com.dauviet.energy.api;

import jakarta.validation.Valid;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.energy.api.dto.EnergyRefillRequest;
import com.dauviet.energy.api.dto.EnergyRefillResponse;
import com.dauviet.energy.api.dto.EnergyStateResponse;
import com.dauviet.energy.application.EnergyService;

/**
 * Bề mặt đọc Thể lực của learner hiện tại (GAME-02) + Viện Thái Y
 * (GAME-07 Issue #28). Identity luôn lấy từ JWT — không nhận userId,
 * không tin thời gian client.
 *
 * <p>{@code POST /refills} mua/dùng một vật phẩm Viện Thái Y — atomic
 * (trừ Điểm Sử Ký + cộng Thể lực trong một tx) và idempotent qua
 * {@code Idempotency-Key} bắt buộc (retry mạng không trừ điểm/cộng
 * energy hai lần).
 */
@RestController
@RequestMapping("/api/v1/me/energy")
public class EnergyController {

    private final EnergyService service;
    private final JwtSubjectExtractor subjects;

    public EnergyController(EnergyService service,
                            JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    /** Trạng thái Thể lực hiện tại + ví Điểm Sử Ký + catalog Viện Thái Y. */
    @GetMapping
    public EnergyStateResponse state(@AuthenticationPrincipal Jwt jwt) {
        return service.stateOf(subjects.userId(jwt));
    }

    /**
     * GAME-07: refill Thể lực bằng một vật phẩm Viện Thái Y.
     * Idempotency-Key BẮT BUỘC — client mobile sinh UUID v4 mỗi lần bấm.
     * Server quyết eligible/cooldown/price, client chỉ render.
     */
    @PostMapping("/refills")
    public EnergyRefillResponse refill(
            @AuthenticationPrincipal Jwt jwt,
            @RequestHeader("Idempotency-Key") String idempotencyKey,
            @Valid @RequestBody EnergyRefillRequest req) {
        return service.refill(subjects.userId(jwt), req.remedyCode(),
                idempotencyKey);
    }
}
