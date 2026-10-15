package com.dauviet.learning.handler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.handler.SelectionHandlers.EvidenceSelectHandler;
import com.dauviet.learning.handler.SelectionHandlers.HypothesisChoiceHandler;
import com.fasterxml.jackson.databind.JsonNode;

class SelectionHandlersTest {

    private final EvidenceSelectHandler evidenceSelect = new EvidenceSelectHandler();
    private final HypothesisChoiceHandler hypothesis = new HypothesisChoiceHandler();

    private static JsonNode snapshotWithEvidence() {
        return HandlerTestSupport.json(
                "{\"stages\":[{\"id\":\"s1\",\"type\":\"EVIDENCE\",\"activities\":[]}],"
              + "\"evidence\":[{\"id\":\"e1\"},{\"id\":\"e2\"},{\"id\":\"e3\"}]}");
    }

    @Test
    void evidenceSelect_validSelection_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\"],\"minRequired\":2}}");
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e1\",\"e2\"]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("selectedCount").asInt()).isEqualTo(2);
    }

    @Test
    void evidenceSelect_belowMin_inProgress() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\"],\"minRequired\":2}}");
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e1\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.IN_PROGRESS);
        assertThat(r.completed()).isFalse();
    }

    @Test
    void evidenceSelect_idOutsideSnapshot_rejected() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e9\"]}}");
        assertThatThrownBy(() -> evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e9\"]}")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("snapshot");
    }

    @Test
    void evidenceSelect_idNotVisible_rejected() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\"]}}");
        assertThatThrownBy(() -> evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e2\"]}")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("selectable");
    }

    @Test
    void hypothesisChoice_recordsForVerification() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"hc\",\"type\":\"HYPOTHESIS_CHOICE\",\"config\":{"
              + "\"hypotheses\":[{\"id\":\"h1\"},{\"id\":\"h2\"}]}}");
        ActivityResult r = hypothesis.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("hc",
                        "{\"hypothesisId\":\"h1\",\"evidenceIds\":[\"e1\",\"e3\"]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("hypothesisId").asText()).isEqualTo("h1");
        assertThat(r.output().get("evidenceIds").size()).isEqualTo(2);
    }

    @Test
    void hypothesisChoice_unknownHypothesis_rejected() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"hc\",\"type\":\"HYPOTHESIS_CHOICE\",\"config\":{"
              + "\"hypotheses\":[{\"id\":\"h1\"}]}}");
        assertThatThrownBy(() -> hypothesis.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("hc", "{\"hypothesisId\":\"h9\"}")))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void hypothesisChoice_unknownEvidence_rejected() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"hc\",\"type\":\"HYPOTHESIS_CHOICE\",\"config\":{"
              + "\"hypotheses\":[{\"id\":\"h1\"}]}}");
        assertThatThrownBy(() -> hypothesis.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("hc",
                        "{\"hypothesisId\":\"h1\",\"evidenceIds\":[\"e9\"]}")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("snapshot");
    }
}
