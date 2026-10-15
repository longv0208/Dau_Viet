package com.dauviet.learning.snapshot;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.dauviet.lesson.domain.SnapshotCorruptException;
import com.fasterxml.jackson.databind.JsonNode;

/**
 * In-memory view of one pinned lesson_versions.snapshot_json. Built once per
 * request by the runtime service; handlers/resolvers consume read-only.
 * Malformed required structure fails fast with SnapshotCorruptException
 * (500 SNAPSHOT_CORRUPT) — a published snapshot that cannot be interpreted
 * is a data-integrity defect, not learner input.
 */
public class SnapshotModel {

    private final JsonNode root;
    private final List<JsonNode> stages = new ArrayList<>();
    private final Map<String, JsonNode> stageById = new LinkedHashMap<>();
    private final Map<String, JsonNode> activityById = new LinkedHashMap<>();
    private final Map<String, String> stageOfActivity = new LinkedHashMap<>();
    private final Map<String, JsonNode> evidenceById = new LinkedHashMap<>();
    private final Map<String, JsonNode> assetById = new LinkedHashMap<>();

    private SnapshotModel(JsonNode root) {
        this.root = root;
        JsonNode stagesNode = root.get("stages");
        if (stagesNode == null || !stagesNode.isArray() || stagesNode.isEmpty()) {
            throw new SnapshotCorruptException("snapshot.stages missing or empty");
        }
        for (JsonNode stage : stagesNode) {
            String sid = text(stage, "id");
            if (sid == null) {
                throw new SnapshotCorruptException("stage missing id");
            }
            stages.add(stage);
            stageById.put(sid, stage);
            JsonNode acts = stage.get("activities");
            if (acts == null || !acts.isArray()) continue;
            for (JsonNode act : acts) {
                String aid = text(act, "id");
                if (aid == null) {
                    throw new SnapshotCorruptException(
                            "activity missing id in stage " + sid);
                }
                if (activityById.put(aid, act) != null) {
                    throw new SnapshotCorruptException(
                            "duplicate activity id '" + aid + "' in snapshot");
                }
                stageOfActivity.put(aid, sid);
            }
        }
        indexIds(root.get("evidence"), evidenceById);
        indexIds(root.get("assets"), assetById);
    }

    public static SnapshotModel parse(JsonNode snapshotJson) {
        if (snapshotJson == null || !snapshotJson.isObject()) {
            throw new SnapshotCorruptException("snapshot is not an object");
        }
        return new SnapshotModel(snapshotJson);
    }

    public JsonNode root() { return root; }
    public List<JsonNode> stages() { return stages; }

    /** stages[0].id — the entry point per authoring contract. */
    public String entryStageId() {
        return text(stages.get(0), "id");
    }

    public JsonNode stageById(String stageId) {
        return stageById.get(stageId);
    }

    public JsonNode activityById(String activityId) {
        return activityById.get(activityId);
    }

    public String stageIdOf(String activityId) {
        return stageOfActivity.get(activityId);
    }

    public JsonNode evidenceById(String evidenceId) {
        return evidenceById.get(evidenceId);
    }

    public JsonNode assetById(String assetId) {
        return assetById.get(assetId);
    }

    public java.util.Set<String> evidenceIds() {
        return java.util.Collections.unmodifiableSet(evidenceById.keySet());
    }

    public JsonNode completion() {
        return root.get("completion");
    }

    /** Required activities of a stage, in array order. */
    public List<JsonNode> requiredActivities(String stageId) {
        List<JsonNode> out = new ArrayList<>();
        JsonNode stage = stageById.get(stageId);
        if (stage == null) return out;
        JsonNode acts = stage.get("activities");
        if (acts == null || !acts.isArray()) return out;
        for (JsonNode a : acts) {
            if (a.path("required").asBoolean(false)) out.add(a);
        }
        return out;
    }

    /** First required activity id of a stage; null when the stage has none. */
    public String firstRequiredActivityId(String stageId) {
        List<JsonNode> req = requiredActivities(stageId);
        return req.isEmpty() ? null : text(req.get(0), "id");
    }

    /** All activities of a stage, in array order. */
    public List<JsonNode> activitiesOf(String stageId) {
        List<JsonNode> out = new ArrayList<>();
        JsonNode stage = stageById.get(stageId);
        if (stage == null) return out;
        JsonNode acts = stage.get("activities");
        if (acts != null && acts.isArray()) acts.forEach(out::add);
        return out;
    }

    /** nextStageIds of a stage, in declared order. */
    public List<String> nextStageIds(String stageId) {
        List<String> out = new ArrayList<>();
        JsonNode stage = stageById.get(stageId);
        if (stage == null) return out;
        JsonNode ids = stage.get("nextStageIds");
        if (ids != null && ids.isArray()) {
            ids.forEach(n -> { if (n.isTextual()) out.add(n.asText()); });
        }
        return out;
    }

    static String text(JsonNode node, String field) {
        JsonNode v = node == null ? null : node.get(field);
        return v != null && v.isTextual() ? v.asText() : null;
    }

    private static void indexIds(JsonNode array, Map<String, JsonNode> out) {
        if (array == null || !array.isArray()) return;
        for (JsonNode item : array) {
            String id = text(item, "id");
            if (id != null) out.put(id, item);
        }
    }
}
