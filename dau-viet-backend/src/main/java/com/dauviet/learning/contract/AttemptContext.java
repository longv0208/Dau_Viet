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
 * `attemptCounts` is the retry-budget ledger keyed by activityId — it lives
 * outside `priorOutputs` because dependent-output invalidation deletes
 * outputs but must never refund spent attempts (TASK-0020 round-3).
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
        Map<String, JsonNode> priorOutputs,
        Map<String, Integer> attemptCounts) {

    /** Legacy constructor — cursor + ledger unknown (unit tests). */
    public AttemptContext(UUID attemptId, UUID userId, UUID lessonVersionId,
                          String stageId, String activityId, JsonNode activity,
                          JsonNode snapshot, Map<String, JsonNode> priorOutputs) {
        this(attemptId, userId, lessonVersionId, stageId, activityId,
                null, activity, snapshot, priorOutputs, null);
    }

    /** Pre-ledger constructor — cursor known, ledger absent. */
    public AttemptContext(UUID attemptId, UUID userId, UUID lessonVersionId,
                          String stageId, String activityId,
                          String currentActivityId, JsonNode activity,
                          JsonNode snapshot, Map<String, JsonNode> priorOutputs) {
        this(attemptId, userId, lessonVersionId, stageId, activityId,
                currentActivityId, activity, snapshot, priorOutputs, null);
    }

    /** Prior submissions against the retry budget (ledger first, output fallback). */
    public int priorAttemptCount() {
        if (attemptCounts != null && attemptCounts.containsKey(activityId)) {
            return attemptCounts.get(activityId);
        }
        JsonNode prior = priorOutputs == null ? null : priorOutputs.get(activityId);
        return prior != null && prior.isObject()
                ? prior.path("attemptCount").asInt(0) : 0;
    }
}
