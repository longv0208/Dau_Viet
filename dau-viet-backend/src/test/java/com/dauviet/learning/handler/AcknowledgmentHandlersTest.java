package com.dauviet.learning.handler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.domain.SnapshotInvalidForActivityException;
import com.dauviet.learning.handler.AcknowledgmentHandlers.ReadHandler;
import com.dauviet.learning.handler.AcknowledgmentHandlers.ReflectionPromptHandler;
import com.dauviet.learning.handler.AcknowledgmentHandlers.ViewImageHandler;
import com.fasterxml.jackson.databind.JsonNode;

class AcknowledgmentHandlersTest {

    private final ReadHandler read = new ReadHandler();
    private final ViewImageHandler viewImage = new ViewImageHandler();
    private final ReflectionPromptHandler reflection = new ReflectionPromptHandler();

    private static JsonNode snapshotWithAsset(String assetId) {
        return HandlerTestSupport.json(
                "{\"stages\":[{\"id\":\"s1\",\"type\":\"CONTEXT\",\"activities\":[]}],"
              + "\"assets\":[{\"id\":\"" + assetId + "\"}]}");
    }

    @Test
    void read_anyWellformedSubmit_completes() {
        JsonNode act = HandlerTestSupport.json("{\"id\":\"r1\",\"type\":\"READ\"}");
        ActivityResult r = read.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithAsset("x")),
                HandlerTestSupport.sub("r1", "{}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.COMPLETED);
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("viewed").asBoolean()).isTrue();
    }

    @Test
    void viewImage_knownAsset_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"v1\",\"type\":\"VIEW_IMAGE\",\"config\":{\"imageAssetId\":\"a9\"}}");
        ActivityResult r = viewImage.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithAsset("a9")),
                HandlerTestSupport.sub("v1", "{}"));
        assertThat(r.completed()).isTrue();
    }

    @Test
    void viewImage_unknownAsset_snapshotInvalid() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"v1\",\"type\":\"VIEW_IMAGE\",\"config\":{\"imageAssetId\":\"zz\"}}");
        assertThatThrownBy(() -> viewImage.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithAsset("a9")),
                HandlerTestSupport.sub("v1", "{}")))
                .isInstanceOf(SnapshotInvalidForActivityException.class);
    }

    @Test
    void reflection_nonEmptyText_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"rp\",\"type\":\"REFLECTION_PROMPT\",\"config\":{\"prompt\":\"why?\"}}");
        ActivityResult r = reflection.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithAsset("x")),
                HandlerTestSupport.sub("rp", "{\"text\":\"because history\"}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("text").asText()).isEqualTo("because history");
    }

    @Test
    void reflection_validOptionId_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"rp\",\"type\":\"REFLECTION_PROMPT\","
              + "\"config\":{\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}]}}");
        ActivityResult r = reflection.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithAsset("x")),
                HandlerTestSupport.sub("rp", "{\"optionId\":\"o2\"}"));
        assertThat(r.completed()).isTrue();
    }

    @Test
    void reflection_emptyTextAndNoOption_400() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"rp\",\"type\":\"REFLECTION_PROMPT\",\"config\":{\"prompt\":\"why?\"}}");
        assertThatThrownBy(() -> reflection.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithAsset("x")),
                HandlerTestSupport.sub("rp", "{\"text\":\"  \"}")))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void reflection_textOverLimit_400() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"rp\",\"type\":\"REFLECTION_PROMPT\",\"config\":{\"prompt\":\"why?\"}}");
        String longText = "x".repeat(4001);
        assertThatThrownBy(() -> reflection.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithAsset("x")),
                HandlerTestSupport.sub("rp", "{\"text\":\"" + longText + "\"}")))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
