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
 *         discoveredMarkerIds:[], currentStageId, currentActivityId}.
 * Never serialized to learners wholesale — API DTOs pick fields.
 */
public class AttemptState {

    private final Set<String> completedActivityIds = new LinkedHashSet<>();
    private final Set<String> discoveredMarkerIds = new LinkedHashSet<>();
    private final Map<String, JsonNode> outputs = new LinkedHashMap<>();
    private String currentStageId;
    private String currentActivityId;

    public Set<String> completedActivityIds() { return completedActivityIds; }
    public Set<String> discoveredMarkerIds() { return discoveredMarkerIds; }
    public Map<String, JsonNode> outputs() { return outputs; }
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
    }

    public ObjectNode toJson() {
        ObjectNode node = JsonNodeFactory.instance.objectNode();
        ArrayNode completed = node.putArray("completedActivityIds");
        completedActivityIds.forEach(completed::add);
        ArrayNode discovered = node.putArray("discoveredMarkerIds");
        discoveredMarkerIds.forEach(discovered::add);
        ObjectNode outs = node.putObject("outputs");
        outputs.forEach(outs::set);
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
        if (json.hasNonNull("currentStageId")) s.currentStageId = json.get("currentStageId").asText();
        if (json.hasNonNull("currentActivityId")) s.currentActivityId = json.get("currentActivityId").asText();
        return s;
    }
}
