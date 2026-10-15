package com.dauviet.learning.handler;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import com.dauviet.learning.contract.ActivitySubmission;
import com.dauviet.learning.contract.AttemptContext;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/** Shared builders for handler unit tests. */
final class HandlerTestSupport {

    static final ObjectMapper OM = new ObjectMapper();

    private HandlerTestSupport() {
    }

    static JsonNode json(String text) {
        try {
            return OM.readTree(text);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    static AttemptContext ctx(JsonNode activity, JsonNode snapshot,
                              Map<String, JsonNode> priorOutputs) {
        return new AttemptContext(UUID.randomUUID(), UUID.randomUUID(),
                UUID.randomUUID(), "stage-1", activity.path("id").asText("a1"),
                activity, snapshot, priorOutputs == null ? Map.of() : priorOutputs);
    }

    static AttemptContext ctx(JsonNode activity, JsonNode snapshot) {
        return ctx(activity, snapshot, new LinkedHashMap<>());
    }

    static ActivitySubmission sub(String activityId, String answerJson) {
        return new ActivitySubmission(UUID.randomUUID(), activityId,
                json(answerJson), null);
    }

    /** Snapshot skeleton: evidence[] + assets[] arrays for handlers needing them. */
    static JsonNode snapshot(String evidenceIds) {
        StringBuilder ev = new StringBuilder("[");
        String[] ids = evidenceIds.split(",");
        for (int i = 0; i < ids.length; i++) {
            if (ids[i].isBlank()) continue;
            ev.append(i > 0 ? "," : "").append("{\"id\":\"").append(ids[i].trim())
              .append("\",\"title\":\"e\"}");
        }
        return json("{\"stages\":[{\"id\":\"s1\",\"type\":\"EVIDENCE\",\"activities\":[]}],"
                  + "\"evidence\":" + ev + "],\"assets\":[]}");
    }
}
