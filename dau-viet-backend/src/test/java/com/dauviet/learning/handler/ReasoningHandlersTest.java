package com.dauviet.learning.handler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.LinkedHashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.handler.ReasoningHandlers.CerHandler;
import com.dauviet.learning.handler.ReasoningHandlers.ReasoningConnectHandler;
import com.dauviet.learning.handler.ReasoningHandlers.VerificationHandler;
import com.fasterxml.jackson.databind.JsonNode;

class ReasoningHandlersTest {

    private final ReasoningConnectHandler reasoning = new ReasoningConnectHandler();
    private final VerificationHandler verification = new VerificationHandler();
    private final CerHandler cer = new CerHandler();

    private static JsonNode snapshot() {
        return HandlerTestSupport.json(
                "{\"stages\":[{\"id\":\"s1\",\"type\":\"VERIFICATION\",\"activities\":[]}],"
              + "\"evidence\":[{\"id\":\"e1\"},{\"id\":\"e2\"},{\"id\":\"e3\"}]}");
    }

    @Test
    void reasoningConnect_validRelations_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"rc\",\"type\":\"REASONING_CONNECT\",\"config\":{"
              + "\"nodes\":[{\"id\":\"n1\"},{\"id\":\"n2\"},{\"id\":\"n3\"}],"
              + "\"allowedRelations\":[\"causes\",\"contradicts\"]}}");
        ActivityResult r = reasoning.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"},"
                        + "               {\"from\":\"n3\",\"to\":\"n1\",\"relation\":\"contradicts\"}]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("relationCount").asInt()).isEqualTo(2);
    }

    @Test
    void reasoningConnect_undeclaredNode_rejected() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"rc\",\"type\":\"REASONING_CONNECT\",\"config\":{"
              + "\"nodes\":[{\"id\":\"n1\"},{\"id\":\"n2\"}],"
              + "\"allowedRelations\":[\"causes\"]}}");
        assertThatThrownBy(() -> reasoning.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n1\",\"to\":\"n9\",\"relation\":\"causes\"}]}")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("node");
    }

    @Test
    void reasoningConnect_disallowedRelation_rejected() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"rc\",\"type\":\"REASONING_CONNECT\",\"config\":{"
              + "\"nodes\":[{\"id\":\"n1\"},{\"id\":\"n2\"}],"
              + "\"allowedRelations\":[\"causes\"]}}");
        assertThatThrownBy(() -> reasoning.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"likes\"}]}")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("not allowed");
    }

    private static JsonNode verificationActivity(String extraConfig) {
        return HandlerTestSupport.json(
                "{\"id\":\"vf\",\"type\":\"VERIFICATION\",\"config\":{"
              + "\"requiredEvidenceIds\":[\"e1\",\"e2\"]" + extraConfig + "}}");
    }

    private static Map<String, JsonNode> priorHypothesis(String hypothesisId, String evidenceCsv) {
        Map<String, JsonNode> prior = new LinkedHashMap<>();
        prior.put("hc", HandlerTestSupport.json(
                "{\"hypothesisId\":\"" + hypothesisId + "\",\"evidenceIds\":["
                + evidenceCsv + "]}"));
        return prior;
    }

    @Test
    void verification_allRequiredEvidence_supported() {
        ActivityResult r = verification.evaluate(
                HandlerTestSupport.ctx(verificationActivity(""), snapshot(),
                        priorHypothesis("h1", "\"e1\",\"e2\",\"e3\"")),
                HandlerTestSupport.sub("vf", "{\"acknowledged\":true}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.SUPPORTED);
        assertThat(r.completed()).isTrue();
    }

    @Test
    void verification_incompleteEvidence_partial() {
        ActivityResult r = verification.evaluate(
                HandlerTestSupport.ctx(verificationActivity(""), snapshot(),
                        priorHypothesis("h1", "\"e1\"")),
                HandlerTestSupport.sub("vf", "{\"acknowledged\":true}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.PARTIAL);
        assertThat(r.completed()).isFalse();
    }

    @Test
    void verification_noHypothesis_contradicted() {
        ActivityResult r = verification.evaluate(
                HandlerTestSupport.ctx(verificationActivity(""), snapshot(),
                        new LinkedHashMap<>()),
                HandlerTestSupport.sub("vf", "{\"acknowledged\":true}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.CONTRADICTED);
        assertThat(r.completed()).isFalse();
    }

    @Test
    void verification_wrongExpectedHypothesis_contradicted() {
        ActivityResult r = verification.evaluate(
                HandlerTestSupport.ctx(
                        verificationActivity(",\"expectedHypothesis\":\"h2\""), snapshot(),
                        priorHypothesis("h1", "\"e1\",\"e2\"")),
                HandlerTestSupport.sub("vf", "{\"acknowledged\":true}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.CONTRADICTED);
    }

    @Test
    void verification_outputNeverEchoes_requiredEvidenceIds() {
        ActivityResult r = verification.evaluate(
                HandlerTestSupport.ctx(verificationActivity(""), snapshot(),
                        priorHypothesis("h1", "\"e1\",\"e2\"")),
                HandlerTestSupport.sub("vf", "{\"acknowledged\":true}"));
        assertThat(r.output().has("requiredEvidenceIds")).isFalse();
        assertThat(r.output().has("expectedHypothesis")).isFalse();
    }

    @Test
    void cer_validClaimReasoning_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"cer\",\"type\":\"CER\",\"config\":{"
              + "\"rubric\":{\"criteria\":[\"clarity\"]},"
              + "\"requiredEvidenceIds\":[\"e1\"]}}");
        ActivityResult r = cer.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("cer",
                        "{\"claim\":\"the empire fell due to internal strife\","
                        + "\"evidenceIds\":[\"e1\"],"
                        + "\"reasoning\":\"the records show repeated civil wars\"}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("claim").asText()).contains("internal strife");
        // requiredEvidenceIds never leaks
        assertThat(r.output().has("requiredEvidenceIds")).isFalse();
    }

    @Test
    void cer_shortClaim_rejected() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"cer\",\"type\":\"CER\",\"config\":{\"rubric\":{\"criteria\":[\"c\"]}}}");
        assertThatThrownBy(() -> cer.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("cer",
                        "{\"claim\":\"short\",\"reasoning\":\"also too short\"}")))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
