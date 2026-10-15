package com.dauviet.lesson.application;

import org.springframework.stereotype.Service;

import com.dauviet.lesson.draft.DraftSchema;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Produces the learner-safe view of a snapshot (or a draft, for preview).
 * Removes every key in {@link DraftSchema#LEARNER_HIDDEN_KEYS} anywhere inside
 * `config`, `validation` and `feedback` — recursively — plus the whole
 * `validation` object's answer-bearing members. Stage-level
 * `requiredEvidenceIds` are also hidden: they name the expected sources.
 * Never mutates the input: a deep copy is stripped.
 */
@Service
public class LearnerProjectionService {

    /** Fields stripped wholesale from each activity: answer-bearing by shape. */
    private static final java.util.Set<String> ACTIVITY_SERVER_ONLY =
            java.util.Set.of("validation");

    /** Fields stripped wholesale from each stage: expected-source metadata. */
    private static final java.util.Set<String> STAGE_SERVER_ONLY =
            java.util.Set.of("requiredEvidenceIds");

    /**
     * Fields stripped wholesale from each activity beyond `validation`:
     * `evidenceRefs` names the exact expected sources — a leak when the
     * activity wants learners to discover evidence themselves. Renderer-facing
     * references stay inside `config.visibleEvidenceIds`/`visibleSourceIds`
     * (whitelisted), so removing `evidenceRefs` loses nothing.
     */
    private static final java.util.Set<String> ACTIVITY_HIDDEN_TOP =
            java.util.Set.of("evidenceRefs");

    /**
     * Deep-copies `snapshot` and returns the learner-safe projection.
     * Works on both snapshot_json and draft_json shapes (stages/activities).
     */
    public ObjectNode project(JsonNode snapshot) {
        if (snapshot == null || !snapshot.isObject()) {
            return snapshot == null
                    ? com.fasterxml.jackson.databind.node.JsonNodeFactory.instance.objectNode()
                    : snapshot.deepCopy();
        }
        ObjectNode copy = (ObjectNode) snapshot.deepCopy();
        stripContainer(copy);
        JsonNode stages = copy.get("stages");
        if (stages != null && stages.isArray()) {
            for (JsonNode stage : stages) {
                if (!stage.isObject()) continue;
                ObjectNode s = (ObjectNode) stage;
                STAGE_SERVER_ONLY.forEach(s::remove);
                stripContainer(s);
                JsonNode acts = s.get("activities");
                if (acts == null || !acts.isArray()) continue;
                for (JsonNode act : acts) {
                    if (!act.isObject()) continue;
                    ObjectNode a = (ObjectNode) act;
                    ACTIVITY_SERVER_ONLY.forEach(a::remove);
                    ACTIVITY_HIDDEN_TOP.forEach(a::remove);
                    stripContainer(a);
                }
            }
        }
        return copy;
    }

    /**
     * Recursively removes LEARNER_HIDDEN_KEYS leaf names from `config`,
     * `feedback` and `validation` subtrees at any shape — `validation` is
     * normally an object dropped wholesale, but a list-shaped value must not
     * leak hidden keys either.
     */
    private void stripContainer(ObjectNode node) {
        stripValue(node.get("config"));
        stripValue(node.get("feedback"));
        stripValue(node.get("validation"));
    }

    private void stripValue(JsonNode value) {
        if (value == null) return;
        if (value.isObject()) {
            stripHiddenKeys((ObjectNode) value);
        } else if (value.isArray()) {
            stripArray(value);
        }
    }

    private void stripArray(JsonNode array) {
        for (JsonNode item : array) {
            stripValue(item);
        }
    }

    /** Removes hidden leaf names at every depth of the object tree. */
    private void stripHiddenKeys(ObjectNode node) {
        var it = node.fields();
        var toStrip = new java.util.ArrayList<String>();
        var nested = new java.util.ArrayList<JsonNode>();
        while (it.hasNext()) {
            var e = it.next();
            if (DraftSchema.LEARNER_HIDDEN_KEYS.contains(e.getKey())) {
                toStrip.add(e.getKey());
            } else if (e.getValue().isContainerNode()) {
                nested.add(e.getValue());
            }
        }
        toStrip.forEach(node::remove);
        for (JsonNode child : nested) {
            stripValue(child);
        }
    }
}
