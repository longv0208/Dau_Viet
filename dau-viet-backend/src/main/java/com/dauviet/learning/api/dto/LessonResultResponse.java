package com.dauviet.learning.api.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * Response of GET /attempts/{id}/result — persisted lesson_results row.
 * `rewards`/`itemsUnlocked` (TASK-0023, additive) liệt kê bút toán thưởng
 * và vật phẩm CHÍNH attempt này đã kích hoạt — client hiển thị thật,
 * không POST lần hai để "nhận thưởng".
 */
public record LessonResultResponse(
        UUID attemptId,
        UUID lessonVersionId,
        String status,
        BigDecimal score,
        JsonNode result,
        Instant completedAt,
        Instant startedAt,
        java.util.List<com.dauviet.reward.api.dto
                .RewardTransactionResponse> rewards,
        java.util.List<com.dauviet.reward.api.dto
                .InventoryItemResponse> itemsUnlocked,
        java.util.List<UUID> newlyUnlockedDossiers,
        java.util.List<CompleteAttemptResponse.UnlockedLocationCue> newlyUnlockedLocations) {

    public LessonResultResponse {
        newlyUnlockedDossiers = newlyUnlockedDossiers == null
                ? java.util.List.of()
                : java.util.List.copyOf(newlyUnlockedDossiers);
        newlyUnlockedLocations = newlyUnlockedLocations == null
                ? java.util.List.of()
                : java.util.List.copyOf(newlyUnlockedLocations);
    }

    public LessonResultResponse(
            UUID attemptId,
            UUID lessonVersionId,
            String status,
            BigDecimal score,
            JsonNode result,
            Instant completedAt,
            Instant startedAt,
            java.util.List<com.dauviet.reward.api.dto
                    .RewardTransactionResponse> rewards,
            java.util.List<com.dauviet.reward.api.dto
                    .InventoryItemResponse> itemsUnlocked) {
        this(attemptId, lessonVersionId, status, score, result, completedAt,
                startedAt, rewards, itemsUnlocked,
                java.util.List.of(), java.util.List.of());
    }
}
