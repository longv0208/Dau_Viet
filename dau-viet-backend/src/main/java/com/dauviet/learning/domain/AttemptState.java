package com.dauviet.learning.domain;

import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Server-internal state carried in learner_attempts.state_json.
 * Shape: {completedActivityIds:[], outputs:{activityId:{...}},
 *         discoveredMarkerIds:[], attemptCounts:{activityId:n},
 *         currentStageId, currentActivityId}.
 * Never serialized to learners wholesale — API DTOs pick fields.
 * `attemptCounts` is the retry-budget ledger: it survives dependent-output
 * invalidation so a Verification bound by maxAttempts cannot have its spent
 * attempts erased by an upstream re-submit (TASK-0020 round-3).
 */
public class AttemptState {

    private final Set<String> completedActivityIds = new LinkedHashSet<>();
    private final Set<String> discoveredMarkerIds = new LinkedHashSet<>();
    private final Map<String, JsonNode> outputs = new LinkedHashMap<>();
    private final Map<String, Integer> attemptCounts = new LinkedHashMap<>();
    private String currentStageId;
    private String currentActivityId;

    public Set<String> completedActivityIds() { return completedActivityIds; }
    public Set<String> discoveredMarkerIds() { return discoveredMarkerIds; }
    public Map<String, JsonNode> outputs() { return outputs; }
    public Map<String, Integer> attemptCounts() { return attemptCounts; }
    public String currentStageId() { return currentStageId; }
    public String currentActivityId() { return currentActivityId; }

    public void setCurrentStageId(String id) { this.currentStageId = id; }
    public void setCurrentActivityId(String id) { this.currentActivityId = id; }

    public void recordOutput(String activityId, JsonNode output) {
        outputs.put(activityId, output);
    }

    public void markCompleted(String activityId) {
        completedActivityIds.add(activityId);
    }

    public boolean isCompleted(String activityId) {
        return completedActivityIds.contains(activityId);
    }

    /**
     * Dependent-output invalidation (Learning Flow 2.0): drop the stored
     * output + completion mark of an activity that consumed a since-revised
     * upstream answer, forcing re-verification instead of stale credit.
     */
    public void removeCompleted(String activityId) {
        completedActivityIds.remove(activityId);
    }

    public void removeOutput(String activityId) {
        outputs.remove(activityId);
        // attemptCounts deliberately untouched: the retry budget belongs to
        // the learner's effort, not to the invalidated output. Erasing it
        // would let a bounded activity (Verification maxAttempts, remedial
        // windows) loop forever — each upstream re-submit would refund tries.
    }

    /** Record one more submission against the retry-budget ledger. */
    public int bumpAttemptCount(String activityId) {
        int n = attemptCounts.getOrDefault(activityId, 0) + 1;
        attemptCounts.put(activityId, n);
        return n;
    }

    public ObjectNode toJson() {
        ObjectNode node = JsonNodeFactory.instance.objectNode();
        ArrayNode completed = node.putArray("completedActivityIds");
        completedActivityIds.forEach(completed::add);
        ArrayNode discovered = node.putArray("discoveredMarkerIds");
        discoveredMarkerIds.forEach(discovered::add);
        ObjectNode outs = node.putObject("outputs");
        outputs.forEach(outs::set);
        if (!attemptCounts.isEmpty()) {
            ObjectNode counts = node.putObject("attemptCounts");
            attemptCounts.forEach(counts::put);
        }
        if (currentStageId != null) node.put("currentStageId", currentStageId);
        if (currentActivityId != null) node.put("currentActivityId", currentActivityId);
        return node;
    }

    public static AttemptState fromJson(JsonNode json) {
        AttemptState s = new AttemptState();
        if (json == null || !json.isObject()) return s;
        JsonNode completed = json.get("completedActivityIds");
        if (completed != null && completed.isArray()) {
            completed.forEach(n -> { if (n.isTextual()) s.completedActivityIds.add(n.asText()); });
        }
        JsonNode discovered = json.get("discoveredMarkerIds");
        if (discovered != null && discovered.isArray()) {
            discovered.forEach(n -> { if (n.isTextual()) s.discoveredMarkerIds.add(n.asText()); });
        }
        JsonNode outs = json.get("outputs");
        if (outs != null && outs.isObject()) {
            outs.fields().forEachRemaining(e -> s.outputs.put(e.getKey(), e.getValue()));
        }
        JsonNode counts = json.get("attemptCounts");
        if (counts != null && counts.isObject()) {
            counts.fields().forEachRemaining(
                    e -> s.attemptCounts.put(e.getKey(), e.getValue().asInt(0)));
        }
        if (json.hasNonNull("currentStageId")) s.currentStageId = json.get("currentStageId").asText();
        if (json.hasNonNull("currentActivityId")) s.currentActivityId = json.get("currentActivityId").asText();
        return s;
    }
}
