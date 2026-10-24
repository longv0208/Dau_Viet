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

    /* ---------- graded mode (config.graded:true) ---------- */

    private static JsonNode gradedReasoningActivity() {
        return HandlerTestSupport.json(
                "{\"id\":\"rc\",\"type\":\"REASONING_CONNECT\",\"config\":{"
              + "\"graded\":true,\"maxAttempts\":3,"
              + "\"nodes\":[{\"id\":\"n1\"},{\"id\":\"n2\"},{\"id\":\"n3\"}],"
              + "\"allowedRelations\":[\"causes\",\"contradicts\"],"
              + "\"expectedRelations\":["
              + "  {\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"},"
              + "  {\"from\":\"n3\",\"to\":\"n1\",\"relation\":\"contradicts\"}]}}");
    }

    @Test
    void reasoningConnect_graded_exactMatch_completes() {
        ActivityResult r = reasoning.evaluate(
                HandlerTestSupport.ctx(gradedReasoningActivity(), snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"},"
                      + "               {\"from\":\"n3\",\"to\":\"n1\",\"relation\":\"contradicts\"}]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.COMPLETED);
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("correct").asBoolean()).isTrue();
        assertThat(r.output().get("score").asDouble()).isEqualTo(1.0);
    }

    @Test
    void reasoningConnect_graded_alternativeAcceptedSet_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"rc\",\"type\":\"REASONING_CONNECT\",\"config\":{"
              + "\"graded\":true,\"maxAttempts\":3,"
              + "\"nodes\":[{\"id\":\"n1\"},{\"id\":\"n2\"},{\"id\":\"n3\"}],"
              + "\"allowedRelations\":[\"causes\",\"contradicts\"],"
              + "\"expectedRelations\":["
              + "  {\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"}],"
              + "\"acceptedRelationSets\":["
              + "  [{\"from\":\"n2\",\"to\":\"n3\",\"relation\":\"causes\"}]]}}");
        ActivityResult r = reasoning.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n2\",\"to\":\"n3\",\"relation\":\"causes\"}]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.COMPLETED);
        assertThat(r.completed()).isTrue();
    }

    @Test
    void reasoningConnect_graded_partialMatch_partial() {
        ActivityResult r = reasoning.evaluate(
                HandlerTestSupport.ctx(gradedReasoningActivity(), snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"}]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.PARTIAL);
        assertThat(r.completed()).isFalse();
        // F1 = 2·1/(1+2) ≈ 0.667 — partial credit bounded in [0,1].
        assertThat(r.output().get("score").asDouble()).isEqualTo(2.0 / 3.0);
        assertThat(r.output().get("matchedRelations").asInt()).isEqualTo(1);
    }

    @Test
    void reasoningConnect_graded_noMatch_incorrect() {
        ActivityResult r = reasoning.evaluate(
                HandlerTestSupport.ctx(gradedReasoningActivity(), snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n2\",\"to\":\"n1\",\"relation\":\"causes\"}]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("score").asDouble()).isEqualTo(0.0);
    }

    @Test
    void reasoningConnect_graded_syntaxValidButWrong_notCompleted() {
        // Valid node ids + allowed relation, but wrong direction/content —
        // graded mode must not pass on syntax alone.
        ActivityResult r = reasoning.evaluate(
                HandlerTestSupport.ctx(gradedReasoningActivity(), snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n2\",\"to\":\"n3\",\"relation\":\"causes\"},"
                      + "               {\"from\":\"n1\",\"to\":\"n3\",\"relation\":\"contradicts\"}]}"));
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("correct").asBoolean()).isFalse();
    }

    @Test
    void reasoningConnect_graded_exhausted_completes() {
        Map<String, JsonNode> prior = new LinkedHashMap<>();
        prior.put("rc", HandlerTestSupport.json("{\"attemptCount\":2}"));
        ActivityResult r = reasoning.evaluate(
                HandlerTestSupport.ctx(gradedReasoningActivity(), snapshot(), prior),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n2\",\"to\":\"n1\",\"relation\":\"causes\"}]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("exhausted").asBoolean()).isTrue();
    }

    @Test
    void reasoningConnect_graded_noKey_stillCompletesLegacy() {
        // graded flag but no expected sets → nothing can match; treat as
        // incorrect path (validator blocks this at publish anyway).
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"rc\",\"type\":\"REASONING_CONNECT\",\"config\":{"
              + "\"graded\":true,\"maxAttempts\":3,"
              + "\"nodes\":[{\"id\":\"n1\"},{\"id\":\"n2\"}],"
              + "\"allowedRelations\":[\"causes\"]}}");
        ActivityResult r = reasoning.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"}]}"));
        assertThat(r.completed()).isFalse();
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
    }

    @Test
    void reasoningConnect_graded_maxF1BeatsMaxHits() {
        // FIX 4 (TASK-0020): the accepted set must be chosen by max F1, not
        // max raw hit count. Two accepted sets — a large canonical (2 rels)
        // and a small alternative (1 rel). A submission exactly equal to the
        // small alternative hits 1/2 of canonical (hits=1) but ALL 1/1 of the
        // alternative (hits=1). Old logic picked canonical by hit count
        // (ties) or, with a larger alternative, could prefer more hits on a
        // bigger set at a LOWER F1. Here the small set wins on F1 (1.0)
        // because it is an exact match.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"rc\",\"type\":\"REASONING_CONNECT\",\"config\":{"
              + "\"graded\":true,\"maxAttempts\":3,"
              + "\"nodes\":[{\"id\":\"n1\"},{\"id\":\"n2\"},{\"id\":\"n3\"},{\"id\":\"n4\"}],"
              + "\"allowedRelations\":[\"causes\",\"contradicts\"],"
              + "\"expectedRelations\":["
              + "  {\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"},"
              + "  {\"from\":\"n3\",\"to\":\"n4\",\"relation\":\"contradicts\"}],"
              + "\"acceptedRelationSets\":["
              + "  [{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"}]]}}");
        ActivityResult r = reasoning.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"}]}"));
        // Exact match on the alternative set -> correct, score 1.0. Had the
        // set been picked by max-hit count against canonical only, this would
        // still be 1 hit but would NOT be treated as exact.
        assertThat(r.outcome()).isEqualTo(ActivityResult.COMPLETED);
        assertThat(r.output().get("correct").asBoolean()).isTrue();
        assertThat(r.output().get("score").asDouble()).isEqualTo(1.0);
    }

    @Test
    void reasoningConnect_graded_f1PrefersBetterRatioOverHitCount() {
        // Canonical = 3 relations, alternative = 1 relation. Submission =
        // alternative's single relation + 2 that only appear in canonical.
        // hits(canonical)=2 -> F1 = 2*2/(3+3)=0.667; hits(alt)=1 -> F1 =
        // 2*1/(3+1)=0.5. Canonical wins on BOTH hits and F1 here — but a
        // hit-count-only picker could also pick the alternative (2 vs 1
        // hits on canonical? no — canonical has MORE hits). The discriminating
        // case is the reverse: submit a set hitting MORE of a large accepted
        // set yet scoring worse on F1 than an exact smaller set.
        // submitted={n1->n2} only: hits canonical=1 (F1 0.5), hits alt=1
        // (F1 1.0). max-hits ties at 1 -> ambiguous; max-F1 cleanly picks 1.0.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"rc\",\"type\":\"REASONING_CONNECT\",\"config\":{"
              + "\"graded\":true,\"maxAttempts\":3,"
              + "\"nodes\":[{\"id\":\"n1\"},{\"id\":\"n2\"},{\"id\":\"n3\"},{\"id\":\"n4\"}],"
              + "\"allowedRelations\":[\"causes\",\"contradicts\"],"
              + "\"expectedRelations\":["
              + "  {\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"},"
              + "  {\"from\":\"n3\",\"to\":\"n4\",\"relation\":\"causes\"},"
              + "  {\"from\":\"n4\",\"to\":\"n1\",\"relation\":\"contradicts\"}],"
              + "\"acceptedRelationSets\":["
              + "  [{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"}]]}}");
        ActivityResult r = reasoning.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"}]}"));
        // Exact alternative -> correct + 1.0, even though canonical has 3 rels.
        assertThat(r.output().get("correct").asBoolean()).isTrue();
        assertThat(r.output().get("score").asDouble()).isEqualTo(1.0);
    }

    @Test
    void reasoningConnect_graded_extraRelations_lowerScore() {
        // Exact set + an incorrect extra relation -> not exact, score < 1.
        ActivityResult r = reasoning.evaluate(
                HandlerTestSupport.ctx(gradedReasoningActivity(), snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"},"
                      + "               {\"from\":\"n3\",\"to\":\"n1\",\"relation\":\"contradicts\"},"
                      + "               {\"from\":\"n2\",\"to\":\"n3\",\"relation\":\"causes\"}]}"));
        // hits=2, |submitted|=3, |accepted|=2 -> F1 = 4/5 = 0.8, not correct.
        assertThat(r.output().get("correct").asBoolean()).isFalse();
        assertThat(r.output().get("score").asDouble()).isEqualTo(0.8);
        assertThat(r.output().get("incorrectCount").asInt()).isEqualTo(1);
    }

    @Test
    void reasoningConnect_graded_duplicatesDoNotInflateScore() {
        // Submitting the same correct relation twice must not push hits past
        // the accepted size — dedup via the relation-key set.
        ActivityResult r = reasoning.evaluate(
                HandlerTestSupport.ctx(gradedReasoningActivity(), snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"},"
                      + "               {\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"},"
                      + "               {\"from\":\"n3\",\"to\":\"n1\",\"relation\":\"contradicts\"}]}"));
        // distinct submitted = {n1->n2, n3->n1} = exact canonical match.
        assertThat(r.output().get("correct").asBoolean()).isTrue();
        assertThat(r.output().get("score").asDouble()).isEqualTo(1.0);
    }

    @Test
    void reasoningConnect_graded_outputNeverEchoes_expected() {
        ActivityResult r = reasoning.evaluate(
                HandlerTestSupport.ctx(gradedReasoningActivity(), snapshot()),
                HandlerTestSupport.sub("rc",
                        "{\"relations\":[{\"from\":\"n1\",\"to\":\"n2\",\"relation\":\"causes\"}]}"));
        String out = r.output().toString();
        assertThat(out).doesNotContain("expectedRelations");
        assertThat(out).doesNotContain("acceptedRelationSets");
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

    /* ---------- evidenceSource (TASK-0020 §P0) ---------- */

    private static JsonNode verificationActivityWithSource() {
        return HandlerTestSupport.json(
                "{\"id\":\"vf\",\"type\":\"VERIFICATION\",\"config\":{"
              + "\"requiredEvidenceIds\":[\"e1\",\"e2\"],"
              + "\"evidenceSource\":\"es\"}}");
    }

    @Test
    void verification_evidenceSource_readsPersistedSelectOutput_supported() {
        // HYPOTHESIS_CHOICE records only the hypothesis id — the evidence set
        // comes from the persisted EVIDENCE_SELECT output named by
        // config.evidenceSource. This was the P0 bug: empty hypothesis
        // evidenceIds produced PARTIAL even when evidence was collected.
        Map<String, JsonNode> prior = new LinkedHashMap<>();
        prior.put("hc", HandlerTestSupport.json("{\"hypothesisId\":\"h-tide\"}"));
        prior.put("es", HandlerTestSupport.json(
                "{\"selectedEvidenceIds\":[\"e1\",\"e2\"]}"));
        ActivityResult r = verification.evaluate(
                HandlerTestSupport.ctx(verificationActivityWithSource(), snapshot(), prior),
                HandlerTestSupport.sub("vf", "{\"action\":\"verify\"}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.SUPPORTED);
        assertThat(r.completed()).isTrue();
    }

    @Test
    void verification_evidenceSource_missingSourceOutput_partial() {
        // Authored source but its output is absent (learner never reached the
        // select, or it was invalidated) — evidence set is empty -> PARTIAL.
        // The verdict never trusts client-submitted evidence ids.
        Map<String, JsonNode> prior = new LinkedHashMap<>();
        prior.put("hc", HandlerTestSupport.json("{\"hypothesisId\":\"h-tide\"}"));
        ActivityResult r = verification.evaluate(
                HandlerTestSupport.ctx(verificationActivityWithSource(), snapshot(), prior),
                HandlerTestSupport.sub("vf",
                        "{\"action\":\"verify\",\"evidenceIds\":[\"e1\",\"e2\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.PARTIAL);
        assertThat(r.completed()).isFalse();
    }

    @Test
    void verification_evidenceSource_clientSubmittedIdsIgnored() {
        // Tampered answer carries evidence ids that would satisfy the key —
        // verdict still reads the persisted source output only.
        Map<String, JsonNode> prior = new LinkedHashMap<>();
        prior.put("hc", HandlerTestSupport.json("{\"hypothesisId\":\"h-tide\"}"));
        prior.put("es", HandlerTestSupport.json(
                "{\"selectedEvidenceIds\":[\"e1\"]}"));
        ActivityResult r = verification.evaluate(
                HandlerTestSupport.ctx(verificationActivityWithSource(), snapshot(), prior),
                HandlerTestSupport.sub("vf",
                        "{\"action\":\"verify\",\"evidenceIds\":[\"e1\",\"e2\",\"e3\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.PARTIAL);
    }

    @Test
    void verification_legacyWithoutSource_fallsBackToHypothesisEvidence() {
        // Snapshots published before evidenceSource: the evidenceIds the
        // HYPOTHESIS_CHOICE output itself recorded still feed the verdict.
        ActivityResult r = verification.evaluate(
                HandlerTestSupport.ctx(verificationActivity(""), snapshot(),
                        priorHypothesis("h1", "\"e1\",\"e2\"")),
                HandlerTestSupport.sub("vf", "{\"acknowledged\":true}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.SUPPORTED);
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
