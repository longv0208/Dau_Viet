package com.dauviet.learning.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.dauviet.learning.contract.LessonCompletion;

/**
 * Response of POST /attempts/{id}/complete — the completion verdict plus the
 * persisted result facts. `alreadyCompleted` is true when the attempt was
 * finished by an earlier call (idempotent replay path). `newlyUnlockedDossiers`
 * (GAME-04 additive) = dossier ids mở MỚI trong lần complete này — rỗng khi
 * replay/không đạt milestone; client dùng để hiện cue một lần.
 *
 * STREAK-01 additive: `streak*` chỉ set khi ngày học được công nhận lần đầu —
 * client dùng để chạy animation lửa N → N+1. Replay vào nhánh
 * alreadyCompleted trả null (không phát lại animation).
 */
public record CompleteAttemptResponse(
        UUID attemptId,
        String status,
        boolean alreadyCompleted,
        Instant completedAt,
        LessonCompletion completion,
        AttemptProgressResponse.Progress progress,
        List<UUID> newlyUnlockedDossiers,
        StreakInfo streak) {

    /** Thông tin streak do server trả sau khi ghi nhận ngày học. */
    public record StreakInfo(
            /** true = ngày vừa được công nhận mới (animation chạy). */
            boolean dayRecorded,
            /** Chuỗi hiện tại SAU khi ghi — hiển thị khi dayRecorded=true. */
            int currentStreak,
            int longestStreak,
            /** Ngày VN được công nhận. */
            java.time.LocalDate studyDate,
            /** Đồng hồ server lúc ghi — client dùng làm mốc freshness cho
             * state streak, KHÔNG bịa từ đồng hồ thiết bị (clock skew). */
            Instant serverTime) {
    }

    /** Replay/old-shape path: không có dossier mới trong lần này. */
    public static CompleteAttemptResponse of(UUID attemptId, String status,
            boolean alreadyCompleted, Instant completedAt,
            LessonCompletion completion,
            AttemptProgressResponse.Progress progress) {
        return new CompleteAttemptResponse(attemptId, status, alreadyCompleted,
                completedAt, completion, progress, List.of(), null);
    }

    /** Full-shape: completion mới + optional streak info (null khi không ghi). */
    public static CompleteAttemptResponse withStreak(UUID attemptId,
            String status, boolean alreadyCompleted, Instant completedAt,
            LessonCompletion completion,
            AttemptProgressResponse.Progress progress,
            List<UUID> newlyUnlockedDossiers, StreakInfo streak) {
        return new CompleteAttemptResponse(attemptId, status, alreadyCompleted,
                completedAt, completion, progress, newlyUnlockedDossiers,
                streak);
    }
}
