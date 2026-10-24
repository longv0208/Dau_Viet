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
    void evidenceSelect_graded_selectAll_neverFullCredit() {
        // TASK-0020 §P3: select-all used to read correct=false but score=1.0.
        // F1 bounds the score — extra wrong picks pull it below 1.0 while
        // still crediting the hits.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],\"maxAttempts\":3}}");
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("es",
                        "{\"selectedEvidenceIds\":[\"e1\",\"e2\",\"e3\"]}"));
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("correct").asBoolean()).isFalse();
        // F1 = 2*2 / (3+2) = 0.8 — extras penalised, hits still counted.
        assertThat(r.output().get("score").asDouble()).isEqualTo(0.8);
        assertThat(r.outcome()).isEqualTo(ActivityResult.PARTIAL);
    }

    @Test
    void evidenceSelect_graded_duplicateIds_noInflation() {
        // Duplicates must not inflate hits: [e1,e1,e2] dedupes to {e1,e2}
        // before scoring — exact match, score 1.0.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],\"maxAttempts\":3}}");
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("es",
                        "{\"selectedEvidenceIds\":[\"e1\",\"e1\",\"e2\"]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("correct").asBoolean()).isTrue();
        assertThat(r.output().get("score").asDouble()).isEqualTo(1.0);
    }

    @Test
    void evidenceSelect_graded_allWrong_scoreZero() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\"],\"maxAttempts\":3}}");
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctx(act, snapshotWithEvidence()),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e2\",\"e3\"]}"));
        assertThat(r.output().get("score").asDouble()).isEqualTo(0.0);
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
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

    /* ---------- remedial retry (TASK-0020 round-3 FIX 1) ---------- */

    @Test
    void evidenceSelect_remedial_afterExhaustionAndHopBack_completesForProgress() {
        // es exhausted (attemptCount>=maxAttempts) then the learner was sent
        // back by a downstream REVISE hop — cursor sits on es again. With
        // remedialAttempts=1 the single remedial submission is the LAST one:
        // it carries the remedial marker for audit but must still complete-
        // for-progress — otherwise the cursor can never leave and the
        // soft-lock this fix removes returns in the other direction.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],"
              + "\"maxAttempts\":2,\"remedialAttempts\":1}}");
        java.util.Map<String, JsonNode> prior = new java.util.LinkedHashMap<>();
        prior.put("es", HandlerTestSupport.json(
                "{\"attemptCount\":2,\"exhausted\":true}"));
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctxAtCursor(act, snapshotWithEvidence(),
                        prior, "es"),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e1\"]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("remedial").asBoolean()).isTrue();
        assertThat(r.output().get("attemptCount").asInt()).isEqualTo(3);
    }

    @Test
    void evidenceSelect_remedial_budgetLeft_staysIncomplete() {
        // remedialAttempts=2 -> attempt 3 of (2+2) is NOT the last remedial
        // try, so completed stays false and the cursor holds for one more
        // honest remediation attempt.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],"
              + "\"maxAttempts\":2,\"remedialAttempts\":2}}");
        java.util.Map<String, JsonNode> prior = new java.util.LinkedHashMap<>();
        prior.put("es", HandlerTestSupport.json(
                "{\"attemptCount\":2,\"exhausted\":true}"));
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctxAtCursor(act, snapshotWithEvidence(),
                        prior, "es"),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e1\"]}"));
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("remedial").asBoolean()).isTrue();
        assertThat(r.output().get("attemptCount").asInt()).isEqualTo(3);
    }

    @Test
    void evidenceSelect_remedial_correctOnRemediation_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],"
              + "\"maxAttempts\":2,\"remedialAttempts\":1}}");
        java.util.Map<String, JsonNode> prior = new java.util.LinkedHashMap<>();
        prior.put("es", HandlerTestSupport.json(
                "{\"attemptCount\":2,\"exhausted\":true}"));
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctxAtCursor(act, snapshotWithEvidence(),
                        prior, "es"),
                HandlerTestSupport.sub("es",
                        "{\"selectedEvidenceIds\":[\"e1\",\"e2\"]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.outcome()).isEqualTo(ActivityResult.COMPLETED);
        assertThat(r.output().get("correct").asBoolean()).isTrue();
    }

    @Test
    void evidenceSelect_remedial_noBudget_exhaustedStaysCompleted() {
        // No remedialAttempts configured -> exhausted stays completed (the
        // legacy soft-lock-avoidance contract); remediation is opt-in.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],\"maxAttempts\":2}}");
        java.util.Map<String, JsonNode> prior = new java.util.LinkedHashMap<>();
        prior.put("es", HandlerTestSupport.json(
                "{\"attemptCount\":2,\"exhausted\":true}"));
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctxAtCursor(act, snapshotWithEvidence(),
                        prior, "es"),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e1\"]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().has("remedial")).isFalse();
    }

    @Test
    void evidenceSelect_remedial_wrongOnRemediation_stillHonest() {
        // Remedial miss keeps correct:false + real F1 — no credit inflation.
        // Budget left (attempt 3 < 2+2) so completed stays false for the
        // next remedial try.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],"
              + "\"maxAttempts\":2,\"remedialAttempts\":2}}");
        java.util.Map<String, JsonNode> prior = new java.util.LinkedHashMap<>();
        prior.put("es", HandlerTestSupport.json(
                "{\"attemptCount\":2,\"exhausted\":true}"));
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctxAtCursor(act, snapshotWithEvidence(),
                        prior, "es"),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e3\"]}"));
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("correct").asBoolean()).isFalse();
        assertThat(r.output().get("score").asDouble()).isEqualTo(0.0);
    }

    @Test
    void evidenceSelect_remedial_lastRetry_wrong_completesForProgress() {
        // Last remedial attempt (attemptNo == maxAttempts+remedialAttempts)
        // must complete-for-progress even when wrong — otherwise the cursor
        // can never leave and the soft-lock returns. Verdict stays honest.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],"
              + "\"maxAttempts\":2,\"remedialAttempts\":1}}");
        java.util.Map<String, JsonNode> prior = new java.util.LinkedHashMap<>();
        prior.put("es", HandlerTestSupport.json(
                "{\"attemptCount\":2,\"exhausted\":true}"));
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctxAtCursor(act, snapshotWithEvidence(),
                        prior, "es"),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e3\"]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("remedial").asBoolean()).isTrue();
        assertThat(r.output().get("correct").asBoolean()).isFalse();
        assertThat(r.output().get("score").asDouble()).isEqualTo(0.0);
    }

    @Test
    void evidenceSelect_overBudget_correctCannotUpgrade() {
        // TASK-0020 final FIX 1: attempt 4 exceeds maxAttempts(2)+remedial(1)
        // — even an exact-match answer must NOT rewrite the locked verdict.
        // The activity stays completed-for-progress (cursor moves on, no
        // 409 soft-lock) and keeps the last recorded score (0.0).
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],"
              + "\"maxAttempts\":2,\"remedialAttempts\":1}}");
        java.util.Map<String, JsonNode> prior = new java.util.LinkedHashMap<>();
        prior.put("es", HandlerTestSupport.json(
                "{\"attemptCount\":3,\"exhausted\":true,\"correct\":false,"
              + "\"score\":0.0}"));
        java.util.Map<String, Integer> counts = new java.util.LinkedHashMap<>();
        counts.put("es", 3);
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctxLedger(act, snapshotWithEvidence(),
                        prior, "es", counts),
                HandlerTestSupport.sub("es",
                        "{\"selectedEvidenceIds\":[\"e1\",\"e2\"]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
        assertThat(r.output().get("correct").asBoolean()).isFalse();
        assertThat(r.output().get("score").asDouble()).isEqualTo(0.0);
        assertThat(r.output().get("budgetExhausted").asBoolean()).isTrue();
        assertThat(r.output().get("attemptCount").asInt()).isEqualTo(4);
    }

    @Test
    void evidenceSelect_overBudget_wrong_staysHonest() {
        // Over-budget + wrong answer: still bounded terminal, no crash.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],"
              + "\"maxAttempts\":2,\"remedialAttempts\":1}}");
        java.util.Map<String, JsonNode> prior = new java.util.LinkedHashMap<>();
        prior.put("es", HandlerTestSupport.json(
                "{\"attemptCount\":3,\"exhausted\":true,\"correct\":false,"
              + "\"score\":0.6666666666666666}"));
        java.util.Map<String, Integer> counts = new java.util.LinkedHashMap<>();
        counts.put("es", 3);
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctxLedger(act, snapshotWithEvidence(),
                        prior, "es", counts),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e3\"]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("correct").asBoolean()).isFalse();
        assertThat(r.output().get("score").asDouble())
                .isEqualTo(0.6666666666666666);
        assertThat(r.output().get("budgetExhausted").asBoolean()).isTrue();
    }

    @Test
    void evidenceSelect_remedial_cursorElsewhere_notRemedial() {
        // Cursor NOT on es (learner revisiting from forward path is impossible
        // via the submit guard, but a stale priorOutputs record must not make
        // this submission remedial — completed stays true).
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"es\",\"type\":\"EVIDENCE_SELECT\",\"config\":{"
              + "\"visibleEvidenceIds\":[\"e1\",\"e2\",\"e3\"],\"graded\":true,"
              + "\"acceptedEvidenceIds\":[\"e1\",\"e2\"],"
              + "\"maxAttempts\":2,\"remedialAttempts\":1}}");
        java.util.Map<String, JsonNode> prior = new java.util.LinkedHashMap<>();
        prior.put("es", HandlerTestSupport.json(
                "{\"attemptCount\":2,\"exhausted\":true}"));
        ActivityResult r = evidenceSelect.evaluate(
                HandlerTestSupport.ctxAtCursor(act, snapshotWithEvidence(),
                        prior, "vf1"),
                HandlerTestSupport.sub("es", "{\"selectedEvidenceIds\":[\"e1\"]}"));
        assertThat(r.output().has("remedial")).isFalse();
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
