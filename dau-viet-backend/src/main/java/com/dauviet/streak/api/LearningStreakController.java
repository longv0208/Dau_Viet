package com.dauviet.streak.api;

import java.time.LocalDate;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.streak.api.dto.LearningStreakCalendarResponse;
import com.dauviet.streak.api.dto.LearningStreakResponse;
import com.dauviet.streak.api.dto.StreakShieldPurchaseResponse;
import com.dauviet.streak.application.LearningStreakService;

/**
 * Bề mặt Chuỗi Ngày Học của learner hiện tại (STREAK-01 + STREAK-02).
 * Identity luôn từ JWT — không nhận userId, không tin completedAt client
 * gửi. Ghi streak chỉ qua LearnerAttemptService.doComplete() server-side;
 * endpoint duy nhất ghi trực tiếp là đổi Khiên Bảo Vệ.
 */
@RestController
@RequestMapping("/api/v1/me/streak")
public class LearningStreakController {

    private final LearningStreakService service;
    private final JwtSubjectExtractor subjects;

    public LearningStreakController(LearningStreakService service,
                                    JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    /** Trạng thái chuỗi hiện tại + ngày server theo timezone VN. */
    @GetMapping
    public LearningStreakResponse state(@AuthenticationPrincipal Jwt jwt) {
        return service.stateOf(subjects.userId(jwt));
    }

    /**
     * Lịch sử ngày đã học trong [from, to] — tối đa 92 ngày, vượt quá thì
     * clamp về from+92 để giữ payload nhỏ (đúng contract đọc-only, không
     * ném lỗi cho range dài).
     */
    @GetMapping("/calendar")
    public LearningStreakCalendarResponse calendar(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
            LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
            LocalDate to) {
        return service.calendarOf(subjects.userId(jwt), from, to);
    }

    /**
     * Đổi 20 Điểm Sử Ký lấy 1 Khiên Bảo Vệ Chuỗi — tối đa 3/3 (V51).
     * Idempotency-Key bắt buộc: một key = một giao dịch duy nhất dù
     * retry; 201 = mua thành công lần đầu, 200 = replay trả stored.
     * 422 SHIELD_AT_MAX_CAPACITY khi đã 3/3; 409 INSUFFICIENT_FUNDS khi
     * ví không đủ 20 điểm.
     */
    @PostMapping("/shields")
    public ResponseEntity<StreakShieldPurchaseResponse> buyShield(
            @AuthenticationPrincipal Jwt jwt,
            @RequestHeader("Idempotency-Key") String idempotencyKey) {
        StreakShieldPurchaseResponse res = service.buyShield(
                subjects.userId(jwt), idempotencyKey);
        return ResponseEntity.status(HttpStatus.CREATED).body(res);
    }
}
