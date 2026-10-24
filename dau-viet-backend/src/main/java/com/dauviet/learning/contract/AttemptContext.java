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
 * `currentActivityId` is the persisted cursor BEFORE this submit — an
 * exhausted activity routed back by a REVISE hop sees its own id there and
 * may spend a remedialAttempts budget (TASK-0020 round-3 remediation).
 */
public record AttemptContext(
        UUID attemptId,
        UUID userId,
        UUID lessonVersionId,
        String stageId,
        String activityId,
        String currentActivityId,
        JsonNode activity,
        JsonNode snapshot,
        Map<String, JsonNode> priorOutputs) {

    /** Legacy constructor — cursor unknown (unit tests, pre-cursor callers). */
    public AttemptContext(UUID attemptId, UUID userId, UUID lessonVersionId,
                          String stageId, String activityId, JsonNode activity,
                          JsonNode snapshot, Map<String, JsonNode> priorOutputs) {
        this(attemptId, userId, lessonVersionId, stageId, activityId,
                null, activity, snapshot, priorOutputs);
    }
}
