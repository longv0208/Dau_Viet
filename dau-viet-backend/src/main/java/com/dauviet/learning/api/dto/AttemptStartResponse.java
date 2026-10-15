package com.dauviet.learning.api.dto;

import java.util.UUID;

/** Response of POST /lessons/{id}/attempts — start or resume. */
public record AttemptStartResponse(
        UUID attemptId,
        UUID lessonVersionId,
        String status,
        boolean resumed,
        String currentStageId,
        String currentActivityId) {
}
