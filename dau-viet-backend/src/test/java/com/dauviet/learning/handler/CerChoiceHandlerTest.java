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
        // Canonical TASK-0020 shape: acceptedCombos replaces the legacy
        // flat arrays; minCorrect is gone (partial can never promote).
        return HandlerTestSupport.json(
                "{\"id\":\"cer\",\"type\":\"CER_CHOICE\",\"config\":{"
              + "\"maxAttempts\":3,"
              + "\"claims\":[{\"id\":\"c1\",\"text\":\"A\"},{\"id\":\"c2\",\"text\":\"B\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\",\"text\":\"R1\"},"
              + "{\"id\":\"r2\",\"text\":\"R2\"}],"
              + "\"evidenceOptions\":[{\"id\":\"e1\"},{\"id\":\"e2\"},{\"id\":\"e3\"}],"
              + "\"acceptedCombos\":["
              + "  {\"claimId\":\"c1\",\"evidenceIds\":[\"e1\",\"e2\"],"
              + "   \"reasoningId\":\"r1\"}]}}");
    }

    private static JsonNode legacyActivity() {
        // Snapshot published before acceptedCombos: cartesian expansion of
        // the three flat arrays — kept compatible by the handler.
        return HandlerTestSupport.json(
                "{\"id\":\"cer\",\"type\":\"CER_CHOICE\",\"config\":{"
              + "\"maxAttempts\":3,"
              + "\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
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
        assertThat(r.output().get("score").asDouble()).isEqualTo(1.0);
        assertThat(r.output().get("attemptCount").asInt()).isEqualTo(1);
    }

    @Test
    void extraEvidence_notFullCredit() {
        // TASK-0020 §P4: superset was previously marked fully correct —
        // a wrong extra pick must not earn a complete conclusion. The
        // evidence part no longer matches the combo exactly.
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(activity(), snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c1\",\"evidenceIds\":[\"e1\",\"e2\",\"e3\"],"
                      + "\"reasoningId\":\"r1\"}"));
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("correct").asBoolean()).isFalse();
        // claim + reasoning correct, evidence set differs -> 2/3.
        assertThat(r.output().get("partsCorrect").asInt()).isEqualTo(2);
        assertThat(r.output().get("score").asDouble()).isEqualTo(2.0 / 3.0);
    }

    @Test
    void subsetEvidence_notFullCredit() {
        // Missing one accepted evidence — no full credit either.
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(activity(), snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c1\",\"evidenceIds\":[\"e1\"],"
                      + "\"reasoningId\":\"r1\"}"));
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("partsCorrect").asInt()).isEqualTo(2);
    }

    @Test
    void alternativeCombo_completes() {
        // Multiple valid interpretations: a second authored combo must also
        // grade as fully correct.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"cer\",\"type\":\"CER_CHOICE\",\"config\":{"
              + "\"maxAttempts\":3,"
              + "\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"evidenceOptions\":[{\"id\":\"e1\"},{\"id\":\"e2\"},{\"id\":\"e3\"}],"
              + "\"acceptedCombos\":["
              + "  {\"claimId\":\"c1\",\"evidenceIds\":[\"e1\",\"e2\"],\"reasoningId\":\"r1\"},"
              + "  {\"claimId\":\"c2\",\"evidenceIds\":[\"e3\"],\"reasoningId\":\"r2\"}]}}");
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c2\",\"evidenceIds\":[\"e3\"],"
                      + "\"reasoningId\":\"r2\"}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("correct").asBoolean()).isTrue();
        assertThat(r.output().get("score").asDouble()).isEqualTo(1.0);
    }

    @Test
    void mixedPartsAcrossCombos_notPromoted() {
        // Claim from combo A + evidence from combo B + reasoning from A:
        // per-part overlap exists against both but no single combo matches —
        // this is exactly what minCorrect used to promote. Not correct.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"cer\",\"type\":\"CER_CHOICE\",\"config\":{"
              + "\"maxAttempts\":3,\"minCorrect\":2,"
              + "\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"evidenceOptions\":[{\"id\":\"e1\"},{\"id\":\"e2\"},{\"id\":\"e3\"}],"
              + "\"acceptedCombos\":["
              + "  {\"claimId\":\"c1\",\"evidenceIds\":[\"e1\",\"e2\"],\"reasoningId\":\"r1\"},"
              + "  {\"claimId\":\"c2\",\"evidenceIds\":[\"e3\"],\"reasoningId\":\"r2\"}]}}");
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c1\",\"evidenceIds\":[\"e3\"],"
                      + "\"reasoningId\":\"r1\"}"));
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("correct").asBoolean()).isFalse();
        assertThat(r.output().get("partsCorrect").asInt()).isEqualTo(2);
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
    void exhaustedAfterMaxAttempts_completesForProgressOnly() {
        // TASK-0020 §P4: exhausted = completed-for-progress, correct stays
        // false — knowledgeScore must never credit an unproven conclusion.
        Map<String, JsonNode> prior = new LinkedHashMap<>();
        prior.put("cer", HandlerTestSupport.json("{\"attemptCount\":2}"));
        AttemptContext ctx = HandlerTestSupport.ctx(activity(), snapshotWithEvidence(), prior);
        ActivityResult r = handler.evaluate(ctx,
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c2\",\"evidenceIds\":[\"e3\"],"
                      + "\"reasoningId\":\"r2\"}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("correct").asBoolean()).isFalse();
        assertThat(r.output().get("exhausted").asBoolean()).isTrue();
        assertThat(r.output().get("attemptCount").asInt()).isEqualTo(3);
    }

    @Test
    void legacyFlatKeys_exactComboStillCompletes() {
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(legacyActivity(), snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c1\",\"evidenceIds\":[\"e1\",\"e2\"],"
                      + "\"reasoningId\":\"r1\"}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("correct").asBoolean()).isTrue();
    }

    @Test
    void legacyFlatKeys_supersetNotPromotedByMinCorrect() {
        // Legacy snapshot carrying minCorrect=2: evidence+reasoning match
        // used to promote the pick even with a wrong claim. TASK-0020 removes
        // the promotion — correctness still requires a coherent combination.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"cer\",\"type\":\"CER_CHOICE\",\"config\":{"
              + "\"maxAttempts\":3,\"minCorrect\":2,"
              + "\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"acceptedClaims\":[\"c1\"],"
              + "\"acceptedEvidenceIds\":[\"e1\"],"
              + "\"acceptedReasoningIds\":[\"r1\"]}}");
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c2\",\"evidenceIds\":[\"e1\"],"
                      + "\"reasoningId\":\"r1\"}"));
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("correct").asBoolean()).isFalse();
        assertThat(r.output().get("partsCorrect").asInt()).isEqualTo(2);
    }

    @Test
    void priorEvidenceSource_poolSelectable() {
        // Evidence collected by the upstream activity named in
        // config.priorEvidenceSource is selectable even when not re-declared
        // in evidenceOptions — and only ids the source actually selected.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"cer\",\"type\":\"CER_CHOICE\",\"config\":{"
              + "\"maxAttempts\":3,"
              + "\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"evidenceOptions\":[{\"id\":\"e1\"}],"
              + "\"priorEvidenceSource\":\"es\","
              + "\"acceptedCombos\":["
              + "  {\"claimId\":\"c1\",\"evidenceIds\":[\"e1\"],\"reasoningId\":\"r1\"}]}}");
        Map<String, JsonNode> prior = new LinkedHashMap<>();
        prior.put("es", HandlerTestSupport.json(
                "{\"selectedEvidenceIds\":[\"e3\"]}"));
        // e3 lives in the source pool -> selectable though undeclared.
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence(), prior),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c1\",\"evidenceIds\":[\"e1\",\"e3\"],"
                      + "\"reasoningId\":\"r1\"}"));
        // e3 is not part of the combo -> not fully correct, but accepted as
        // a legal selection (no exception).
        assertThat(r.output().get("correct").asBoolean()).isFalse();
    }

    @Test
    void snapshotEvidence_notReDeclared_stillSelectable() {
        // Snapshot evidence ids are selectable even when absent from
        // evidenceOptions — kept from the original semantics.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"cer\",\"type\":\"CER_CHOICE\",\"config\":{"
              + "\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
              + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
              + "\"acceptedCombos\":["
              + "  {\"claimId\":\"c1\",\"evidenceIds\":[\"e1\"],\"reasoningId\":\"r1\"}]}}");
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c1\",\"evidenceIds\":[\"e1\"],"
                      + "\"reasoningId\":\"r1\"}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("correct").asBoolean()).isTrue();
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
    void output_neverLeaksAnswerKeys() {
        ActivityResult r = handler.evaluate(
                HandlerTestSupport.ctx(activity(), snapshotWithEvidence()),
                HandlerTestSupport.sub("cer",
                        "{\"claimId\":\"c1\",\"evidenceIds\":[\"e1\",\"e2\"],"
                      + "\"reasoningId\":\"r1\"}"));
        String out = r.output().toString();
        assertThat(out).doesNotContain("acceptedCombos");
        assertThat(out).doesNotContain("acceptedClaims");
        assertThat(out).doesNotContain("acceptedEvidenceIds");
        assertThat(out).doesNotContain("acceptedReasoningIds");
    }
}
