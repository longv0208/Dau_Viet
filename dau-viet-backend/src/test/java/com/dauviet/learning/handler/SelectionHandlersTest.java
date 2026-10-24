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

    // P1-A — duplicate submitted ids phải dedupe trước minRequired so
    // [A,A] không thể bypass minRequired=2; output/collection giữ nhất quán.
    @Test
    void evidenceSelect_duplicateIds_belowMin_inProgress() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\"],\"minRequired\":2}}");
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e1\",\"e1\"]}"));
        // [e1,e1] dedupe → 1 distinct < 2 → chưa hoàn thành.
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("selectedCount").asInt()).isEqualTo(1);
        assertThat(r.output().get("selectedEvidenceIds").size()).isEqualTo(1);
    }

    @Test
    void evidenceSelect_duplicateExtra_stillCompletes() {
        // [e1,e2,e1] → dedupe {e1,e2} = 2 đủ minRequired; output giữ distinct.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\"],\"minRequired\":2}}");
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("es",
                        "{\"selectedEvidenceIds\":[\"e1\",\"e2\",\"e1\"]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("selectedCount").asInt()).isEqualTo(2);
        // selectedEvidenceIds output chỉ chứa distinct — collection không
        // ghi trùng.
        assertThat(r.output().get("selectedEvidenceIds").size()).isEqualTo(2);
    }

    /* ---------- graded mode (config.graded:true + acceptedEvidenceIds) ---------- */

    @Test
    void evidenceSelect_graded_exactMatch_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],\"maxAttempts\":2}}");
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e1\",\"e2\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.COMPLETED);
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("correct").asBoolean()).isTrue();
        assertThat(r.output().get("score").asDouble()).isEqualTo(1.0);
    }

    @Test
    void evidenceSelect_graded_partialHit_partialWithScore() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],\"maxAttempts\":3}}");
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e1\",\"e3\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.PARTIAL);
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("score").asDouble()).isEqualTo(0.5);
        assertThat(r.output().get("correctCount").asInt()).isEqualTo(1);
        assertThat(r.output().get("falseCount").asInt()).isEqualTo(1);
    }

    @Test
    void evidenceSelect_graded_noHit_incorrect() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],\"maxAttempts\":3}}");
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e3\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
        assertThat(r.completed()).isFalse();
    }

    @Test
    void evidenceSelect_graded_exhausted_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],\"maxAttempts\":2}}");
        java.util.Map<String, JsonNode> prior = new java.util.LinkedHashMap<>();
        prior.put("es", HandlerTestSupport.json("{\"attemptCount\":1}"));
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence(), prior),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e3\"]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("exhausted").asBoolean()).isTrue();
    }

    @Test
    void evidenceSelect_graded_noKey_fallsBackToLegacy() {
        // graded flag set but no acceptedEvidenceIds → legacy count path.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\"],\"graded\":true,"
              + "\"minRequired\":2}}");
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e1\",\"e2\"]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().has("score")).isFalse();
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
