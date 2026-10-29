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
 *
 * MAP-V2 additive: `newlyUnlockedLocations` chứa các địa điểm di tích vừa mở
 * khóa mới trong cùng transaction complete.
 */
public record CompleteAttemptResponse(
        UUID attemptId,
        String status,
        boolean alreadyCompleted,
        Instant completedAt,
        LessonCompletion completion,
        AttemptProgressResponse.Progress progress,
        List<UUID> newlyUnlockedDossiers,
        StreakInfo streak,
        List<UnlockedLocationCue> newlyUnlockedLocations) {

    public CompleteAttemptResponse {
        newlyUnlockedDossiers = newlyUnlockedDossiers == null ? List.of() : List.copyOf(newlyUnlockedDossiers);
        newlyUnlockedLocations = newlyUnlockedLocations == null ? List.of() : List.copyOf(newlyUnlockedLocations);
    }

    public CompleteAttemptResponse(
            UUID attemptId,
            String status,
            boolean alreadyCompleted,
            Instant completedAt,
            LessonCompletion completion,
            AttemptProgressResponse.Progress progress,
            List<UUID> newlyUnlockedDossiers,
            StreakInfo streak) {
        this(attemptId, status, alreadyCompleted, completedAt, completion,
                progress, newlyUnlockedDossiers, streak, List.of());
    }

    /**
     * Thông tin streak do server trả sau khi ghi nhận ngày học. STREAK-02
     * additive: shieldConsumed = khiên vừa tự trừ để cứu chuỗi;
     * bonusExp/bonusPoints = thưởng chuỗi vừa grant; milestoneDay = mốc
     * 3/7/14/30 nếu đạt (null = không mốc).
     */
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
            Instant serverTime,
            /** Khiên Bảo Vệ vừa tự tiêu hao để cứu chuỗi (bỏ lỡ đúng 1
             * ngày + shieldCount > 0). */
            boolean shieldConsumed,
            /** Số khiên còn lại sau ghi — UI cập nhật card 🛡️ ngay. */
            int shieldCount,
            /** EXP thưởng chuỗi vừa grant trong tx này (0 nếu không). */
            int bonusExp,
            /** Điểm Sử Ký thưởng chuỗi vừa grant trong tx này. */
            int bonusPoints,
            /** Mốc chuỗi đạt (3/7/14/30) nếu có; null = không mốc. */
            Integer milestoneDay) {
    }

    /** Thông tin địa điểm di tích vừa mở khóa trong lượt hoàn thành bài học. */
    public record UnlockedLocationCue(
            UUID locationId,
            String slug,
            String title,
            String kind,
            UUID coverAssetId) {
    }

    /** Replay/old-shape path: không có dossier/location mới trong lần này. */
    public static CompleteAttemptResponse of(UUID attemptId, String status,
            boolean alreadyCompleted, Instant completedAt,
            LessonCompletion completion,
            AttemptProgressResponse.Progress progress) {
        return new CompleteAttemptResponse(attemptId, status, alreadyCompleted,
                completedAt, completion, progress, List.of(), null, List.of());
    }

    /** Full-shape: completion mới + optional streak info (null khi không ghi). */
    public static CompleteAttemptResponse withStreak(UUID attemptId,
            String status, boolean alreadyCompleted, Instant completedAt,
            LessonCompletion completion,
            AttemptProgressResponse.Progress progress,
            List<UUID> newlyUnlockedDossiers, StreakInfo streak) {
        return new CompleteAttemptResponse(attemptId, status, alreadyCompleted,
                completedAt, completion, progress, newlyUnlockedDossiers,
                streak, List.of());
    }

    /** Full-shape kèm danh sách địa điểm vừa mở khóa. */
    public static CompleteAttemptResponse withStreakAndLocations(UUID attemptId,
            String status, boolean alreadyCompleted, Instant completedAt,
            LessonCompletion completion,
            AttemptProgressResponse.Progress progress,
            List<UUID> newlyUnlockedDossiers, StreakInfo streak,
            List<UnlockedLocationCue> newlyUnlockedLocations) {
        return new CompleteAttemptResponse(attemptId, status, alreadyCompleted,
                completedAt, completion, progress, newlyUnlockedDossiers,
                streak, newlyUnlockedLocations);
    }
}
