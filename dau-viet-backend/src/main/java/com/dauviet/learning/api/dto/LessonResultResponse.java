package com.dauviet.learning.api.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

/** Response of GET /attempts/{id}/result — persisted lesson_results row. */
public record LessonResultResponse(
        UUID attemptId,
        UUID lessonVersionId,
        String status,
        BigDecimal score,
        JsonNode result,
        Instant completedAt,
        Instant startedAt) {
}
