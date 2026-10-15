package com.dauviet.learning.api.dto;

import java.time.Instant;
import java.util.UUID;

import com.dauviet.learning.contract.LessonCompletion;

/**
 * Response of POST /attempts/{id}/complete — the completion verdict plus the
 * persisted result facts. `alreadyCompleted` is true when the attempt was
 * finished by an earlier call (idempotent replay path).
 */
public record CompleteAttemptResponse(
        UUID attemptId,
        String status,
        boolean alreadyCompleted,
        Instant completedAt,
        LessonCompletion completion,
        AttemptProgressResponse.Progress progress) {
}
