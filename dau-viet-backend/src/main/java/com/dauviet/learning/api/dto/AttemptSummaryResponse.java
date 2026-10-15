package com.dauviet.learning.api.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * One row of the learner's attempt history / resume list. Carries enough for
 * the mobile client to render a resume card without a second call.
 */
public record AttemptSummaryResponse(
        UUID attemptId,
        UUID lessonId,
        UUID lessonVersionId,
        String status,
        String currentStageId,
        String currentActivityId,
        AttemptProgressResponse.Progress progress,
        Instant startedAt,
        Instant lastActiveAt,
        Instant completedAt) {
}
