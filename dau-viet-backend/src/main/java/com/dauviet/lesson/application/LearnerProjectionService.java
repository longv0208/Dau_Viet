package com.dauviet.lesson.application;

import java.util.List;

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
                    transformActivity(a);
                    ACTIVITY_SERVER_ONLY.forEach(a::remove);
                    ACTIVITY_HIDDEN_TOP.forEach(a::remove);
                    stripContainer(a);
                }
            }
        }
        return copy;
    }

    /**
     * Learner-safe projection of a single snapshot activity node: drops
     * `validation`/`evidenceRefs` and strips hidden keys inside
     * `config`/`feedback`. Never mutates the input.
     */
    public ObjectNode projectActivity(JsonNode activity) {
        if (activity == null || !activity.isObject()) {
            return com.fasterxml.jackson.databind.node.JsonNodeFactory.instance.objectNode();
        }
        ObjectNode copy = (ObjectNode) activity.deepCopy();
        transformActivity(copy);
        ACTIVITY_SERVER_ONLY.forEach(copy::remove);
        ACTIVITY_HIDDEN_TOP.forEach(copy::remove);
        stripContainer(copy);
        return copy;
    }

    /**
     * Per-type learner-facing transforms applied to the copied activity BEFORE
     * hidden-key stripping, so emitted fields are never removed again.
     * These change the *presentation* of authored config without touching the
     * server-side answer keys (which stay in the snapshot for grading).
     */
    private void transformActivity(ObjectNode act) {
        String type = act.path("type").asText("");
        JsonNode config = act.get("config");
        if (config == null || !config.isObject()) return;
        ObjectNode cfg = (ObjectNode) config;
        switch (type) {
            case "MATCHING" -> transformMatching(act.path("id").asText(""), cfg);
            case "DRAG_ORDER" -> transformDragOrder(act.path("id").asText(""), cfg);
            default -> { }
        }
    }

    /**
     * MATCHING: `pairs[{left,right}]` declares the correct mapping by position —
     * keeping it would hand learners the answer. Replace with two independent
     * columns `leftItems[]`/`rightItems[]` ({id,label}), each sorted by its own
     * deterministic key so row index never implies the matching partner.
     * `correctPairs`/`pairs` are stripped from the learner copy only.
     */
    private void transformMatching(String activityId, ObjectNode config) {
        JsonNode pairs = config.get("pairs");
        if (pairs == null || !pairs.isArray()) return;
        var left = new java.util.ArrayList<com.fasterxml.jackson.databind.node.ObjectNode>();
        var right = new java.util.ArrayList<com.fasterxml.jackson.databind.node.ObjectNode>();
        for (JsonNode p : pairs) {
            if (!p.isObject()) continue;
            JsonNode l = p.get("left");
            JsonNode r = p.get("right");
            if (l != null && l.isObject()) {
                left.add(itemNode(l));
            }
            if (r != null && r.isObject()) {
                right.add(itemNode(r));
            }
        }
        // Independent deterministic orderings: left sorted by hash asc,
        // right by hash desc — same input always yields the same two columns,
        // and left[i] never trivially maps to right[i].
        left.sort(java.util.Comparator.comparingInt(n -> sortKey(activityId, n.get("id").asText())));
        right.sort(java.util.Comparator.comparingInt(
                (com.fasterxml.jackson.databind.node.ObjectNode n) ->
                        sortKey(activityId, n.get("id").asText())).reversed());
        var f = com.fasterxml.jackson.databind.node.JsonNodeFactory.instance;
        var leftArr = f.arrayNode();
        var rightArr = f.arrayNode();
        left.forEach(leftArr::add);
        right.forEach(rightArr::add);
        config.remove("pairs");
        config.set("leftItems", leftArr);
        config.set("rightItems", rightArr);
    }

    private com.fasterxml.jackson.databind.node.ObjectNode itemNode(JsonNode side) {
        var f = com.fasterxml.jackson.databind.node.JsonNodeFactory.instance;
        var node = f.objectNode();
        node.put("id", side.path("id").asText(""));
        JsonNode label = side.get("label");
        JsonNode text = side.get("text");
        node.put("label", label != null ? label.asText()
                : text != null ? text.asText() : "");
        return node;
    }

    /** Stable per-(activity,item) sort key; deterministic across JVM runs. */
    private int sortKey(String activityId, String itemId) {
        return java.util.Objects.hash(activityId + "|" + itemId);
    }

    /**
     * DRAG_ORDER: `items[]` is authored in the correct order, so the projected
     * list must present a *different* but stable sequence. Sort by
     * hash(activityId|itemId); if that still equals `expectedOrder` (or the
     * authored order when no expectedOrder) with >=2 items, reverse once.
     */
    private void transformDragOrder(String activityId, ObjectNode config) {
        JsonNode items = config.get("items");
        if (items == null || !items.isArray() || items.size() < 2) return;
        var list = new java.util.ArrayList<JsonNode>();
        items.forEach(list::add);
        list.sort(java.util.Comparator.comparingInt(
                n -> sortKey(activityId, n.path("id").asText())));
        List<String> projected = list.stream()
                .map(n -> n.path("id").asText("")).toList();
        JsonNode expected = config.has("expectedOrder")
                ? config.get("expectedOrder") : config.get("correctOrder");
        List<String> answer = expected != null && expected.isArray()
                ? toIdList(expected)
                : List.of();
        if (answer.isEmpty()) {
            // No explicit key — fall back to the authored items order as the
            // sequence that must not be shown verbatim.
            var authored = new java.util.ArrayList<String>();
            items.forEach(n -> authored.add(n.path("id").asText("")));
            answer = authored;
        }
        if (projected.size() >= 2 && projected.equals(answer)) {
            java.util.Collections.reverse(list);
        }
        var f = com.fasterxml.jackson.databind.node.JsonNodeFactory.instance;
        var arr = f.arrayNode();
        list.forEach(arr::add);
        config.set("items", arr);
    }

    private List<String> toIdList(JsonNode array) {
        var out = new java.util.ArrayList<String>();
        array.forEach(n -> { if (n.isTextual()) out.add(n.asText()); });
        return out;
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
