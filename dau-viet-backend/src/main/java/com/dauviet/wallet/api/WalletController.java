package com.dauviet.wallet.api;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.wallet.api.dto.WalletResponse;
import com.dauviet.wallet.application.WalletService;

/**
 * Điểm Sử Ký của learner hiện tại (ISLAND-BE-01). Identity luôn lấy từ
 * JWT — không nhận userId từ client. Refill endpoint CHƯA mở — GAME-07
 * bổ sung sau khi wallet transactional debit đã hoàn tất.
 */
@RestController
@RequestMapping("/api/v1/me/wallet")
public class WalletController {

    private final WalletService service;
    private final JwtSubjectExtractor subjects;

    public WalletController(WalletService service,
                            JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    /** Số dư + tổng vào/ra + 20 giao dịch gần nhất. */
    @GetMapping
    public WalletResponse wallet(@AuthenticationPrincipal Jwt jwt) {
        return service.walletOf(subjects.userId(jwt));
    }
}
