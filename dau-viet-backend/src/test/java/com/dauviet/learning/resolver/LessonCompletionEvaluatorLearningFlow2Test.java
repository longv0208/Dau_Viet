package com.dauviet.learning.resolver;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

import com.dauviet.learning.contract.LessonCompletion;
import com.dauviet.learning.domain.AttemptState;
import com.dauviet.learning.snapshot.SnapshotModel;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Learning Flow 2.0 regression: REFLECTION stage marked required:false must
 * never gate completion — the learner can skip it entirely and still finish.
 */
class LessonCompletionEvaluatorLearningFlow2Test {

    private static final ObjectMapper OM = new ObjectMapper();
    private final LessonCompletionEvaluator evaluator = new LessonCompletionEvaluator();

    private static JsonNode json(String s) {
        try { return OM.readTree(s); } catch (Exception e) { throw new IllegalStateException(e); }
    }

    private static AttemptState done(String... ids) {
        AttemptState s = new AttemptState();
        for (String id : ids) s.markCompleted(id);
        return s;
    }

    @Test
    void optionalReflectionStage_neverGatesCompletion() {
        // Two required stages + one optional REFLECTION stage. The reflection
        // activity is not required-flagged — publish would reject it if it were.
        JsonNode snap = json("""
                {"stages":[
                  {"id":"s1","type":"EVIDENCE","required":true,"activities":[
                    {"id":"a1","type":"EVIDENCE_SELECT","required":true}],
                   "nextStageIds":["s2"]},
                  {"id":"s2","type":"CONCLUSION","required":true,"activities":[
                    {"id":"a2","type":"CER_CHOICE","required":true}],
                   "nextStageIds":["rf"]},
                  {"id":"rf","type":"REFLECTION","required":false,"activities":[
                    {"id":"rf1","type":"REFLECTION_PROMPT"}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel m = SnapshotModel.parse(snap);
        // All required done, reflection untouched -> complete
        LessonCompletion r = evaluator.evaluate(m, done("a1", "a2"));
        assertThat(r.complete()).isTrue();
        assertThat(r.reason()).isEqualTo(LessonCompletion.DEFAULT_ALL_REQUIRED);
    }

    @Test
    void optionalReflectionStage_unsubmitted_notCountedInTotals() {
        JsonNode snap = json("""
                {"stages":[
                  {"id":"s1","type":"EVIDENCE","required":true,"activities":[
                    {"id":"a1","type":"EVIDENCE_SELECT","required":true}],
                   "nextStageIds":["rf"]},
                  {"id":"rf","type":"REFLECTION","required":false,"activities":[
                    {"id":"rf1","type":"REFLECTION_PROMPT"}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel m = SnapshotModel.parse(snap);
        LessonCompletion r = evaluator.evaluate(m, done("a1"));
        assertThat(r.detail().get("totalRequired").asInt()).isEqualTo(1);
        assertThat(r.detail().get("completedRequired").asInt()).isEqualTo(1);
    }
}
