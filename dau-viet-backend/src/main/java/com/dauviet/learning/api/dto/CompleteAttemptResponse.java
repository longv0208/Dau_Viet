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
 */
public record CompleteAttemptResponse(
        UUID attemptId,
        String status,
        boolean alreadyCompleted,
        Instant completedAt,
        LessonCompletion completion,
        AttemptProgressResponse.Progress progress,
        List<UUID> newlyUnlockedDossiers) {

    /** Replay/old-shape path: không có dossier mới trong lần này. */
    public static CompleteAttemptResponse of(UUID attemptId, String status,
            boolean alreadyCompleted, Instant completedAt,
            LessonCompletion completion,
            AttemptProgressResponse.Progress progress) {
        return new CompleteAttemptResponse(attemptId, status, alreadyCompleted,
                completedAt, completion, progress, List.of());
    }
}
