package com.dauviet.learning.resolver;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

import com.dauviet.learning.contract.LessonCompletion;
import com.dauviet.learning.domain.AttemptState;
import com.dauviet.learning.snapshot.SnapshotModel;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

class LessonCompletionEvaluatorTest {

    private static final ObjectMapper OM = new ObjectMapper();
    private final LessonCompletionEvaluator evaluator = new LessonCompletionEvaluator();

    private static JsonNode json(String s) {
        try { return OM.readTree(s); } catch (Exception e) { throw new IllegalStateException(e); }
    }

    private static JsonNode snapshot(String ignored) {
        return snapshotWithCompletion(null);
    }

    private static JsonNode snapshotWithCompletion(String completionJson) {
        String base = """
                {"stages":[
                  {"id":"s1","type":"CONTEXT","required":true,"activities":[
                    {"id":"a1","type":"READ","required":true},
                    {"id":"a2","type":"READ","required":true}],
                   "nextStageIds":["s2"]},
                  {"id":"s2","type":"EVIDENCE","required":true,"activities":[
                    {"id":"b1","type":"READ","required":true}],
                   "nextStageIds":[]},
                  {"id":"s3","type":"REFLECTION","required":false,"activities":[
                    {"id":"c1","type":"READ","required":true}],
                   "nextStageIds":[]}]%s}
                """.formatted(completionJson == null ? "" : ",\"completion\":" + completionJson);
        return json(base);
    }

    private static AttemptState done(String... ids) {
        AttemptState s = new AttemptState();
        for (String id : ids) s.markCompleted(id);
        return s;
    }

    @Test
    void absentCompletion_defaultAllRequiredRule() {
        SnapshotModel m = SnapshotModel.parse(snapshot(null));
        // 3 required total (a1,a2,b1); c1 lives in optional stage but is still
        // a required activity -> counts in the default rule.
        LessonCompletion partial = evaluator.evaluate(m, done("a1", "a2"));
        assertThat(partial.complete()).isFalse();
        assertThat(partial.reason()).isEqualTo(LessonCompletion.NOT_COMPLETE);

        LessonCompletion doneAll = evaluator.evaluate(m, done("a1", "a2", "b1", "c1"));
        assertThat(doneAll.complete()).isTrue();
        assertThat(doneAll.reason()).isEqualTo(LessonCompletion.DEFAULT_ALL_REQUIRED);
    }

    @Test
    void requireAllRequiredStages_optionalStageIgnored() {
        SnapshotModel m = SnapshotModel.parse(
                snapshotWithCompletion("{\"requireAllRequiredStages\":true}"));
        // complete required stages s1+s2; s3 is optional -> verdict complete
        LessonCompletion r = evaluator.evaluate(m, done("a1", "a2", "b1"));
        assertThat(r.complete()).isTrue();
        assertThat(r.reason()).isEqualTo(LessonCompletion.ALL_REQUIRED_STAGES);
    }

    @Test
    void requireAllRequiredStages_missingActivity_notComplete() {
        SnapshotModel m = SnapshotModel.parse(
                snapshotWithCompletion("{\"requireAllRequiredStages\":true}"));
        LessonCompletion r = evaluator.evaluate(m, done("a1", "b1"));
        assertThat(r.complete()).isFalse();
        assertThat(r.detail().get("missingStageIds").get(0).asText()).isEqualTo("s1");
    }

    @Test
    void requiredStageIds_onlyThoseStagesGate() {
        SnapshotModel m = SnapshotModel.parse(
                snapshotWithCompletion("{\"requiredStageIds\":[\"s2\"]}"));
        LessonCompletion r = evaluator.evaluate(m, done("b1"));
        assertThat(r.complete()).isTrue();
        assertThat(r.reason()).isEqualTo(LessonCompletion.REQUIRED_STAGE_IDS);

        LessonCompletion missing = evaluator.evaluate(m, done("a1", "a2"));
        assertThat(missing.complete()).isFalse();
        assertThat(missing.detail().get("missingStageIds").get(0).asText()).isEqualTo("s2");
    }

    @Test
    void minScore_percentageOfAllRequired() {
        // 4 required activities total (a1,a2,b1,c1) -> each = 25%
        SnapshotModel m = SnapshotModel.parse(
                snapshotWithCompletion("{\"minScore\":75}"));
        assertThat(evaluator.evaluate(m, done("a1", "a2", "b1")).complete()).isTrue();
        assertThat(evaluator.evaluate(m, done("a1", "a2")).complete()).isFalse();
    }

    @Test
    void combinedClauses_allMustHold() {
        SnapshotModel m = SnapshotModel.parse(snapshotWithCompletion(
                "{\"requireAllRequiredStages\":true,\"minScore\":50}"));
        // required stages done but only 3/4 = 75% >= 50 -> complete
        assertThat(evaluator.evaluate(m, done("a1", "a2", "b1")).complete()).isTrue();
        // required stage s2 incomplete -> fail even though score might be ok
        LessonCompletion r = evaluator.evaluate(m, done("a1", "a2", "c1"));
        assertThat(r.complete()).isFalse();
    }

    @Test
    void detail_carriesCounts() {
        SnapshotModel m = SnapshotModel.parse(snapshot(null));
        LessonCompletion r = evaluator.evaluate(m, done("a1"));
        assertThat(r.detail().get("completedRequired").asInt()).isEqualTo(1);
        assertThat(r.detail().get("totalRequired").asInt()).isEqualTo(4);
    }
}
