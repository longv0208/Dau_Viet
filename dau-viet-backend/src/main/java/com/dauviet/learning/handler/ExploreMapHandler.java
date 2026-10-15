package com.dauviet.learning.handler;

import java.util.LinkedHashSet;
import java.util.Set;

import org.springframework.stereotype.Component;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.contract.ActivitySubmission;
import com.dauviet.learning.contract.AttemptContext;
import com.dauviet.lesson.draft.ActivityType;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * EXPLORE_MAP: submit {markerId} ∈ config.markers[].id. Discovery accumulates
 * across submissions via priorOutputs.discoveredMarkerIds; completes when the
 * discovered set covers config.minMarkers (default = all markers).
 */
@Component
public class ExploreMapHandler extends AbstractActivityHandler {

    @Override public ActivityType supports() { return ActivityType.EXPLORE_MAP; }

    @Override
    public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
        JsonNode config = requireConfig(ctx.activity());
        Set<String> markerIds = objectIds(config, "markers");
        String markerId = requireText(sub.answer(), "markerId");
        if (!markerIds.contains(markerId)) {
            throw new IllegalArgumentException("markerId is not a discoverable marker");
        }
        int minMarkers = config.path("minMarkers").asInt(markerIds.size());

        Set<String> discovered = new LinkedHashSet<>();
        JsonNode prior = ctx.priorOutputs().get(ctx.activityId());
        if (prior != null && prior.isObject()) {
            JsonNode prev = prior.get("discoveredMarkerIds");
            if (prev != null && prev.isArray()) {
                prev.forEach(n -> { if (n.isTextual()) discovered.add(n.asText()); });
            }
        }
        discovered.add(markerId);

        boolean done = discovered.size() >= Math.min(minMarkers, markerIds.size());
        JsonNodeFactory f = JsonNodeFactory.instance;
        ObjectNode out = f.objectNode();
        ArrayNode arr = out.putArray("discoveredMarkerIds");
        discovered.forEach(arr::add);
        out.put("discoveredCount", discovered.size());
        return result(done ? ActivityResult.COMPLETED : ActivityResult.IN_PROGRESS,
                done, out, feedbackFor(ctx.activity(),
                        done ? ActivityResult.COMPLETED : ActivityResult.IN_PROGRESS));
    }
}
