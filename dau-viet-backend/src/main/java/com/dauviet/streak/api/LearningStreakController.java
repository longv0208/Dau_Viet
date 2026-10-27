package com.dauviet.streak.api;

import java.time.LocalDate;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.streak.api.dto.LearningStreakCalendarResponse;
import com.dauviet.streak.api.dto.LearningStreakResponse;
import com.dauviet.streak.application.LearningStreakService;

/**
 * Bề mặt đọc Chuỗi Ngày Học của learner hiện tại (STREAK-01). Identity
 * luôn từ JWT — không nhận userId, không tin completedAt client gửi.
 * Không có endpoint tăng streak — duy nhất ghi là LearnerAttemptService
 * .doComplete() server-side.
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
}
