package com.dauviet.learning.handler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.LinkedHashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.dauviet.learning.contract.ActivityResult;
import com.fasterxml.jackson.databind.JsonNode;

class ExploreMapHandlerTest {

    private final ExploreMapHandler handler = new ExploreMapHandler();

    private static JsonNode activity(int minMarkers) {
        return HandlerTestSupport.json(
                "{\"id\":\"em\",\"type\":\"EXPLORE_MAP\",\"config\":{\"markers\":["
              + "{\"id\":\"m1\"},{\"id\":\"m2\"},{\"id\":\"m3\"}]"
              + (minMarkers > 0 ? ",\"minMarkers\":" + minMarkers : "") + "}}");
    }

    private static JsonNode snapshot() {
        return HandlerTestSupport.json(
                "{\"stages\":[{\"id\":\"s1\",\"type\":\"DISCOVERY\",\"activities\":[]}]}");
    }

    @Test
    void firstMarker_inProgress_untilMinReached() {
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(activity(2), snapshot()),
                HandlerTestSupport.sub("em", "{\"markerId\":\"m1\"}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.IN_PROGRESS);
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("discoveredCount").asInt()).isEqualTo(1);
    }

    @Test
    void accumulatesAcrossSubmits_viaPriorOutputs() {
        Map<String, JsonNode> prior = new LinkedHashMap<>();
        ActivityResult first = handler.evaluate(
                HandlerTestSupport.ctx(activity(2), snapshot(), prior),
                HandlerTestSupport.sub("em", "{\"markerId\":\"m1\"}"));
        prior.put("em", first.output());

        ActivityResult second = handler.evaluate(
                HandlerTestSupport.ctx(activity(2), snapshot(), prior),
                HandlerTestSupport.sub("em", "{\"markerId\":\"m2\"}"));
        assertThat(second.outcome()).isEqualTo(ActivityResult.COMPLETED);
        assertThat(second.completed()).isTrue();
        assertThat(second.output().get("discoveredMarkerIds").size()).isEqualTo(2);
    }

    @Test
    void unknownMarker_rejected() {
        assertThatThrownBy(() -> handler.evaluate(
                HandlerTestSupport.ctx(activity(0), snapshot()),
                HandlerTestSupport.sub("em", "{\"markerId\":\"nope\"}")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("marker");
    }

    @Test
    void defaultMinMarkers_isAllMarkers() {
        // no minMarkers configured -> needs all 3
        Map<String, JsonNode> prior = new LinkedHashMap<>();
        for (String m : new String[]{"m1", "m2"}) {
            ActivityResult r = handler.evaluate(
                    HandlerTestSupport.ctx(activity(0), snapshot(), prior),
                    HandlerTestSupport.sub("em", "{\"markerId\":\"" + m + "\"}"));
            prior.put("em", r.output());
            assertThat(r.completed()).isFalse();
        }
        ActivityResult last = handler.evaluate(
                HandlerTestSupport.ctx(activity(0), snapshot(), prior),
                HandlerTestSupport.sub("em", "{\"markerId\":\"m3\"}"));
        assertThat(last.completed()).isTrue();
    }
}
