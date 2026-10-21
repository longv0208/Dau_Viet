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
            case "MULTIPLE_CHOICE" -> transformMultipleChoice(cfg);
            default -> { }
        }
    }

    /**
     * MATCHING: `pairs[{left,right}]` declares the correct mapping by position —
     * keeping it would hand learners the answer. Replace with two independent
     * columns `leftItems[]`/`rightItems[]` ({id,label}).
     *
     * Left column is sorted by the deterministic per-(activity,item) hash.
     * The right column is then DERANGED relative to the real mapping: for every
     * displayed row i, right[i] must not be the correct partner of left[i].
     * A single sorted order cannot guarantee that (some id sets align by hash),
     * so we pick a deterministic rotation offset among candidates 1..n-1 that
     * satisfies the derangement invariant; if no rotation works (pathological
     * id sets) we apply a guaranteed swap-based derangement — never a salted
     * hash that could silently re-align a correct pair.
     * `correctPairs`/`pairs` are stripped from the learner copy only — the
     * server-side snapshot keeps them for grading.
     */
    private void transformMatching(String activityId, ObjectNode config) {
        JsonNode pairs = config.get("pairs");
        if (pairs == null || !pairs.isArray()) return;
        var left = new java.util.ArrayList<com.fasterxml.jackson.databind.node.ObjectNode>();
        var right = new java.util.ArrayList<com.fasterxml.jackson.databind.node.ObjectNode>();
        // partnerByLeft: real server-side mapping so the derangement uses the
        // actual answer, not a positional guess.
        var partnerByLeft = new java.util.HashMap<String, String>();
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
            if (l != null && l.isObject() && r != null && r.isObject()) {
                partnerByLeft.put(l.path("id").asText(""), r.path("id").asText(""));
            }
        }
        left.sort(java.util.Comparator.comparingInt(n -> sortKey(activityId, n.get("id").asText())));
        right.sort(java.util.Comparator.comparingInt(n -> sortKey(activityId, n.get("id").asText())));

        int n = Math.min(left.size(), right.size());
        if (n >= 2) {
            // Try rotation offsets 1..n-1 on the sorted right column; accept the
            // first that guarantees no row shows a correct pair. Deterministic:
            // same input → same offset.
            var rightIds = right.stream().map(x -> x.get("id").asText()).toList();
            int chosen = -1;
            for (int offset = 1; offset < n && chosen < 0; offset++) {
                boolean ok = true;
                for (int i = 0; i < n; i++) {
                    String lid = left.get(i).get("id").asText();
                    String rid = rightIds.get((i + offset) % n);
                    if (rid.equals(partnerByLeft.get(lid))) {
                        ok = false;
                        break;
                    }
                }
                if (ok) chosen = offset;
            }
            if (chosen < 0) {
                // No pure rotation deranges every row (pathological id sets).
                // Guaranteed constructive fix for one-to-one pairings:
                // greedily place a non-partner right at each row, then repair
                // any row still holding its partner by swapping with a row
                // whose candidate keeps both rows non-partnered. This always
                // terminates with a derangement when a perfect matching
                // exists (Hall's condition holds for bijection pairings).
                var fixed = new java.util.ArrayList<com.fasterxml.jackson.databind.node.ObjectNode>(right);
                for (int i = 0; i < n; i++) {
                    String lid = left.get(i).get("id").asText();
                    if (!fixed.get(i).get("id").asText().equals(partnerByLeft.get(lid))) continue;
                    for (int j = 0; j < n; j++) {
                        if (j == i) continue;
                        String candJ = fixed.get(j).get("id").asText();
                        String candI = fixed.get(i).get("id").asText();
                        String lidJ = left.get(j).get("id").asText();
                        // Swap i<->j only if neither row ends up partnered.
                        if (!candJ.equals(partnerByLeft.get(lid))
                                && !candI.equals(partnerByLeft.get(lidJ))) {
                            var tmp = fixed.get(i);
                            fixed.set(i, fixed.get(j));
                            fixed.set(j, tmp);
                            break;
                        }
                    }
                }
                right = new java.util.ArrayList<>(fixed);
            } else {
                var rotated = new java.util.ArrayList<com.fasterxml.jackson.databind.node.ObjectNode>();
                for (int i = 0; i < right.size(); i++) {
                    rotated.add(right.get((i + chosen) % right.size()));
                }
                right = rotated;
            }
        }
        var f = com.fasterxml.jackson.databind.node.JsonNodeFactory.instance;
        var leftArr = f.arrayNode();
        var rightArr = f.arrayNode();
        left.forEach(leftArr::add);
        right.forEach(rightArr::add);
        config.remove("pairs");
        config.set("leftItems", leftArr);
        config.set("rightItems", rightArr);
    }

    /**
     * MULTIPLE_CHOICE legacy compat: drafts authored before the canonical
     * contract used `multiCorrect` without an explicit `multiSelect` flag.
     * Learner renderers key off `multiSelect` to pick checkboxes vs radio —
     * emit multiSelect=true when the legacy key carries multiple answers.
     * `multiCorrect` itself is stripped by LEARNER_HIDDEN_KEYS afterwards.
     */
    private void transformMultipleChoice(ObjectNode config) {
        if (config.has("multiSelect")) return;
        JsonNode legacy = config.get("multiCorrect");
        if (legacy != null && legacy.isArray() && legacy.size() > 1) {
            config.put("multiSelect", true);
        }
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
