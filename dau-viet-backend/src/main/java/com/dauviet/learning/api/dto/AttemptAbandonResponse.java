package com.dauviet.learning.api.dto;

import java.util.UUID;

/** Response of POST /attempts/{id}/abandon — marks IN_PROGRESS → ABANDONED. */
public record AttemptAbandonResponse(
        UUID attemptId,
        UUID lessonVersionId,
        String status) {
}
