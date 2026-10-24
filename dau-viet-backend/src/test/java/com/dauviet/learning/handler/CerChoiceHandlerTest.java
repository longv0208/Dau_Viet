package com.dauviet.learning.handler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.LinkedHashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.contract.AttemptContext;
import com.fasterxml.jackson.databind.JsonNode;

class CerChoiceHandlerTest {

    private final CerChoiceHandler handler = new CerChoiceHandler();

    private static JsonNode snapshotWithEvidence() {
        return HandlerTestSupport.json(
                "{\"stages\":[{\"id\":\"s1\",\"type\":\"CONCLUSION\",\"activities\":[]}],"
              + "\"evidence\":[{\"id\":\"e1\"},{\"id\":\"e2\"},{\"id\":\"e3\"}]}");
    }

    private static JsonNode activity() {
        return HandlerTestSupport.json(
                "{\"id\":\"cer\",\"type\":\"CER_CHOICE\",\"config\":{"
              + "\"graded\":true,\"maxAttempts\":3,\"minCorrect\":3,"
              + "\"claims\":[{\"id\":\"c1\",\"text\":\"A\"},{\"id\":\"c2\",\"text\":\"B\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\",\"text\":\"R1\"},"
              + "{\"id\":\"r2\",\"text\":\"R2\"}],"
              + "\"evidenceOptions\":[{\"id\":\"e1\"},{\"id\":\"e2\"},{\"id\":\"e3\"}],"
              + "\"acceptedClaims\":[\"c1\"],"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],"
              + "\"acceptedReasoningIds\":[\"r1\"]}}");
    }

    @Test
    void allPartsCorrect_completed() {
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(activity(), snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c1\",\"evidenceIds\":[\"e1\",\"e2\"],"
                      + "\"reasoningId\":\"r1\"}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.COMPLETED);
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("partsCorrect").asInt()).isEqualTo(3);
        assertThat(r.output().get("correct").asBoolean()).isTrue();
        assertThat(r.output().get("attemptCount").asInt()).isEqualTo(1);
    }

    @Test
    void extraEvidence_supersetOk() {
        // e3 is a declared evidenceOption but not in the key — superset is fine.
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(activity(), snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c1\",\"evidenceIds\":[\"e1\",\"e2\",\"e3\"],"
                      + "\"reasoningId\":\"r1\"}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("partsCorrect").asInt()).isEqualTo(3);
    }

    @Test
    void onePartWrong_partial() {
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(activity(), snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c2\",\"evidenceIds\":[\"e1\",\"e2\"],"
                      + "\"reasoningId\":\"r1\"}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.PARTIAL);
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("partsCorrect").asInt()).isEqualTo(2);
    }

    @Test
    void allPartsWrong_incorrect() {
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(activity(), snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c2\",\"evidenceIds\":[\"e3\"],"
                      + "\"reasoningId\":\"r2\"}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("partsCorrect").asInt()).isEqualTo(0);
    }

    @Test
    void exhaustedAfterMaxAttempts_completesIncorrect() {
        Map<String, JsonNode> prior = new LinkedHashMap<>();
        prior.put("cer", HandlerTestSupport.json("{\"attemptCount\":2}"));
        AttemptContext ctx = HandlerTestSupport.ctx(activity(), snapshotWithEvidence(), prior);
        ActivityResult r = handler.evaluate(ctx,
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c2\",\"evidenceIds\":[\"e3\"],"
                      + "\"reasoningId\":\"r2\"}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("exhausted").asBoolean()).isTrue();
        assertThat(r.output().get("attemptCount").asInt()).isEqualTo(3);
    }

    @Test
    void unknownClaim_rejected() {
        assertThatThrownBy(() -> handler.evaluate(
                HandlerTestSupport.ctx(activity(), snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c9\",\"evidenceIds\":[\"e1\"],"
                      + "\"reasoningId\":\"r1\"}")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("claimId");
    }

    @Test
    void unknownReasoning_rejected() {
        assertThatThrownBy(() -> handler.evaluate(
                HandlerTestSupport.ctx(activity(), snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c1\",\"evidenceIds\":[\"e1\"],"
                      + "\"reasoningId\":\"r9\"}")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("reasoningId");
    }

    @Test
    void unknownEvidence_rejected() {
        assertThatThrownBy(() -> handler.evaluate(
                HandlerTestSupport.ctx(activity(), snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c1\",\"evidenceIds\":[\"e9\"],"
                      + "\"reasoningId\":\"r1\"}")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("e9");
    }

    @Test
    void snapshotEvidence_notReDeclared_stillSelectable() {
        // prior-source evidence ids may not be re-listed in evidenceOptions —
        // snapshot membership is enough.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"cer\",\"type\":\"CER_CHOICE\",\"config\":{"
              + "\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"acceptedClaims\":[\"c1\"],"
              + "\"acceptedEvidenceIds\":[\"e1\"],"
              + "\"acceptedReasoningIds\":[\"r1\"],\"minCorrect\":2}}");
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c2\",\"evidenceIds\":[\"e1\"],"
                      + "\"reasoningId\":\"r1\"}"));
        // evidence + reasoning correct (2/3 >= minCorrect 2) even though c2 wrong.
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("partsCorrect").asInt()).isEqualTo(2);
    }

    @Test
    void output_neverLeaksAnswerKeys() {
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(activity(), snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c1\",\"evidenceIds\":[\"e1\",\"e2\"],"
                      + "\"reasoningId\":\"r1\"}"));
        String out = r.output().toString();
        assertThat(out).doesNotContain("acceptedClaims");
        assertThat(out).doesNotContain("acceptedEvidenceIds");
        assertThat(out).doesNotContain("acceptedReasoningIds");
    }
}
