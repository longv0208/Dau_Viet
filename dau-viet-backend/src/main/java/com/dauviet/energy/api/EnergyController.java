package com.dauviet.energy.api;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.energy.api.dto.EnergyStateResponse;
import com.dauviet.energy.application.EnergyService;

/**
 * Bề mặt đọc Thể lực của learner hiện tại (GAME-02). Identity luôn lấy từ
 * JWT — không nhận userId, không tin thời gian client. Refill qua Điểm Sử
 * Ký CHƯA mở (§13): không endpoint mua ở đây cho tới khi wallet sẵn sàng.
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

    /** Trạng thái Thể lực hiện tại + mốc hồi kế tiếp do server tính. */
    @GetMapping
    public EnergyStateResponse state(@AuthenticationPrincipal Jwt jwt) {
        return service.stateOf(subjects.userId(jwt));
    }
}
