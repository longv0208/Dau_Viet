package com.dauviet.learning.domain;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

class AttemptStateTest {

    private static final ObjectMapper OM = new ObjectMapper();

    @Test
    void roundTrip_preservesAllFields() {
        AttemptState s = new AttemptState();
        s.markCompleted("a1");
        s.markCompleted("a2");
        s.discoveredMarkerIds().add("m1");
        s.recordOutput("a1", OM.createObjectNode().put("correct", true));
        s.setCurrentStageId("ev");
        s.setCurrentActivityId("mc");

        JsonNode json = s.toJson();
        AttemptState back = AttemptState.fromJson(json);

        assertThat(back.completedActivityIds()).containsExactly("a1", "a2");
        assertThat(back.discoveredMarkerIds()).containsExactly("m1");
        assertThat(back.outputs().get("a1").get("correct").asBoolean()).isTrue();
        assertThat(back.currentStageId()).isEqualTo("ev");
        assertThat(back.currentActivityId()).isEqualTo("mc");
    }

    @Test
    void fromJson_nullOrGarbage_returnsEmpty() {
        assertThat(AttemptState.fromJson(null).completedActivityIds()).isEmpty();
        assertThat(AttemptState.fromJson(OM.createArrayNode()).outputs()).isEmpty();
    }

    @Test
    void toJson_alwaysObject_satisfiesDbCheck() {
        // chk_attempt_state requires jsonb_typeof = 'object' even for fresh state
        assertThat(new AttemptState().toJson().isObject()).isTrue();
    }
}
