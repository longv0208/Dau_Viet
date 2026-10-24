package com.dauviet.learning.handler;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.domain.SnapshotInvalidForActivityException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;

/** Shared helpers: config/answer extraction, id lists, learner-safe results. */
public abstract class AbstractActivityHandler implements ActivityHandler {

    protected JsonNode config(JsonNode activity) {
        JsonNode c = activity == null ? null : activity.get("config");
        return (c != null && c.isObject()) ? c : null;
    }

    protected JsonNode requireConfig(JsonNode activity) {
        JsonNode c = config(activity);
        if (c == null) {
            throw new SnapshotInvalidForActivityException(
                    "activity " + idOf(activity) + " missing config object");
        }
        return c;
    }

    protected String idOf(JsonNode node) {
        JsonNode v = node == null ? null : node.get("id");
        return v != null && v.isTextual() ? v.asText() : "?";
    }

    /** Non-null array field from answer; throws 400-mapped IllegalArgumentException. */
    protected JsonNode requireArray(JsonNode answer, String field) {
        JsonNode v = answer == null ? null : answer.get(field);
        if (v == null || !v.isArray()) {
            throw new IllegalArgumentException(field + " must be an array");
        }
        return v;
    }

    protected String requireText(JsonNode answer, String field) {
        JsonNode v = answer == null ? null : answer.get(field);
        if (v == null || !v.isTextual() || v.asText().isBlank()) {
            throw new IllegalArgumentException(field + " must be a non-empty string");
        }
        return v.asText();
    }

    protected List<String> readIdList(JsonNode answer, String field) {
        List<String> ids = new ArrayList<>();
        requireArray(answer, field).forEach(n -> {
            if (n.isTextual()) ids.add(n.asText());
        });
        return ids;
    }

    protected Set<String> stringIds(JsonNode array) {
        Set<String> ids = new LinkedHashSet<>();
        if (array != null && array.isArray()) {
            array.forEach(n -> { if (n.isTextual()) ids.add(n.asText()); });
        }
        return ids;
    }

    /** Ids of {id:...} objects inside an array field of a config. */
    protected Set<String> objectIds(JsonNode config, String field) {
        Set<String> ids = new LinkedHashSet<>();
        JsonNode arr = config == null ? null : config.get(field);
        if (arr != null && arr.isArray()) {
            for (JsonNode item : arr) {
                JsonNode id = item.get("id");
                if (id != null && id.isTextual()) ids.add(id.asText());
            }
        }
        return ids;
    }

    /**
     * How many times this activity was already submitted in this attempt —
     * derived from the persisted output's attemptCount (retry budget input).
     */
    protected static int priorAttempts(com.dauviet.learning.contract.AttemptContext ctx) {
        JsonNode prior = ctx.priorOutputs().get(ctx.activityId());
        return prior != null && prior.isObject()
                ? prior.path("attemptCount").asInt(0) : 0;
    }

    protected String feedbackFor(JsonNode activity, String outcomeKey) {
        JsonNode fb = activity == null ? null : activity.get("feedback");
        if (fb != null && fb.isObject() && fb.hasNonNull(outcomeKey)) {
            return outcomeKey;
        }
        return null;
    }

    /** Build a learner-safe ActivityResult — output deep-stripped of hidden keys. */
    protected ActivityResult result(String outcome, boolean completed,
                                    JsonNode output, String feedbackCode) {
        ObjectNode safe;
        if (output == null || !output.isObject()) {
            safe = JsonNodeFactory.instance.objectNode();
        } else {
            ObjectNode copy = output.deepCopy();
            stripHiddenKeysDeep(copy);
            safe = copy;
        }
        return new ActivityResult(outcome, completed, safe, feedbackCode);
    }

    /** Recursively remove every LEARNER_HIDDEN_KEYS leaf at any depth/shape. */
    private void stripHiddenKeysDeep(ObjectNode node) {
        var it = node.fields();
        var toRemove = new java.util.ArrayList<String>();
        var nested = new java.util.ArrayList<JsonNode>();
        while (it.hasNext()) {
            var e = it.next();
            if (com.dauviet.lesson.draft.DraftSchema.LEARNER_HIDDEN_KEYS.contains(e.getKey())) {
                toRemove.add(e.getKey());
            } else if (e.getValue().isContainerNode()) {
                nested.add(e.getValue());
            }
        }
        toRemove.forEach(node::remove);
        for (JsonNode child : nested) {
            stripValue(child);
        }
    }

    private void stripValue(JsonNode value) {
        if (value.isObject()) {
            stripHiddenKeysDeep((ObjectNode) value);
        } else if (value.isArray()) {
            value.forEach(this::stripValue);
        }
    }

    protected ActivityResult result(String outcome, boolean completed) {
        return result(outcome, completed, null, null);
    }
}
