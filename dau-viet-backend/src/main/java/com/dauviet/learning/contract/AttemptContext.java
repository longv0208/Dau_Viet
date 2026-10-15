package com.dauviet.learning.contract;

import java.util.Map;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * Server-side evaluation context for one submission against a pinned
 * LessonVersion. Handlers read hidden keys from `activity` (part of the
 * immutable snapshot) but must never emit them into ActivityResult.
 * `priorOutputs` holds each previously submitted activity's stored output
 * (keyed by activityId) for cross-activity rules like VERIFICATION.
 */
public record AttemptContext(
        UUID attemptId,
        UUID userId,
        UUID lessonVersionId,
        String stageId,
        String activityId,
        JsonNode activity,
        JsonNode snapshot,
        Map<String, JsonNode> priorOutputs) {
}
