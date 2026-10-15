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

    /**
     * s1 + s2 are required stages carrying required work (a1,a2,b1); s3 is an
     * OPTIONAL stage (Reflection-style). The legacy fixture carried a
     * `required:true` activity inside s3 — under the stage-gated semantics
     * (P1 review fix) that flag can never gate anything outside an explicit
     * `requiredStageIds` clause, so publish now rejects the shape and the
     * evaluator ignores it. The fixture keeps the activity but drops the
     * contradictory flag; `requiredStageIds` tests below re-flag it via the
     * explicit clause to prove the override still works.
     */
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
                    {"id":"c1","type":"READ"}],
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
        // 3 required total (a1,a2,b1); c1 lives in optional stage s3 and is
        // NOT required-flagged -> does not gate the default rule.
        LessonCompletion partial = evaluator.evaluate(m, done("a1", "a2"));
        assertThat(partial.complete()).isFalse();
        assertThat(partial.reason()).isEqualTo(LessonCompletion.NOT_COMPLETE);

        LessonCompletion doneAll = evaluator.evaluate(m, done("a1", "a2", "b1"));
        assertThat(doneAll.complete()).isTrue();
        assertThat(doneAll.reason()).isEqualTo(LessonCompletion.DEFAULT_ALL_REQUIRED);
    }

    @Test
    void optionalStage_requiredFlaggedActivity_ignoredByDefaultRule() {
        // Legacy/hand-edited snapshot: activity carries required:true inside
        // a required:false stage. The stage flag wins — the activity is
        // optional for progress/completion (publish would reject this shape;
        // runtime stays safe on already-published snapshots).
        JsonNode snap = json("""
                {"stages":[
                  {"id":"s1","type":"CONTEXT","required":true,"activities":[
                    {"id":"a1","type":"READ","required":true}],
                   "nextStageIds":["s3"]},
                  {"id":"s3","type":"REFLECTION","required":false,"activities":[
                    {"id":"c1","type":"READ","required":true}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel m = SnapshotModel.parse(snap);
        // a1 done, c1 untouched -> complete anyway (c1 cannot gate)
        LessonCompletion r = evaluator.evaluate(m, done("a1"));
        assertThat(r.complete()).isTrue();
        assertThat(r.detail().get("totalRequired").asInt()).isEqualTo(1);
    }

    @Test
    void requiredStageIds_explicitClause_overridesStageFlag() {
        // Explicit clause names the OPTIONAL stage s3: author's explicit list
        // wins — activities flagged required inside it gate again.
        JsonNode snap = json("""
                {"stages":[
                  {"id":"s1","type":"CONTEXT","required":true,"activities":[
                    {"id":"a1","type":"READ","required":true}],
                   "nextStageIds":["s3"]},
                  {"id":"s3","type":"REFLECTION","required":false,"activities":[
                    {"id":"c1","type":"READ","required":true}],
                   "nextStageIds":[]}],
                 "completion":{"requiredStageIds":["s3"]}}
                """);
        SnapshotModel m = SnapshotModel.parse(snap);
        assertThat(evaluator.evaluate(m, done("a1")).complete()).isFalse();
        LessonCompletion r = evaluator.evaluate(m, done("c1"));
        assertThat(r.complete()).isTrue();
        assertThat(r.reason()).isEqualTo(LessonCompletion.REQUIRED_STAGE_IDS);
    }

    @Test
    void emptyCompletionObject_fallsBackToDefaultAllRequired() {
        // `completion:{}` (legacy-published or hand-edited) must behave like
        // an absent completion: NOT complete before all required work is done.
        SnapshotModel m = SnapshotModel.parse(snapshotWithCompletion("{}"));
        LessonCompletion fresh = evaluator.evaluate(m, done());
        assertThat(fresh.complete()).isFalse();
        assertThat(fresh.reason()).isEqualTo(LessonCompletion.NOT_COMPLETE);
        assertThat(fresh.detail().get("completedRequired").asInt()).isZero();
        assertThat(fresh.detail().get("totalRequired").asInt()).isEqualTo(3);

        LessonCompletion doneAll = evaluator.evaluate(m, done("a1", "a2", "b1"));
        assertThat(doneAll.complete()).isTrue();
        assertThat(doneAll.reason()).isEqualTo(LessonCompletion.DEFAULT_ALL_REQUIRED);
    }

    @Test
    void completionObjectWithoutActiveClause_fallsBackToDefault() {
        // Clauses present but inert (empty ids array, false flag, null score)
        // are equivalent to `{}` — never an early-complete opt-out.
        SnapshotModel m = SnapshotModel.parse(snapshotWithCompletion(
                "{\"requireAllRequiredStages\":false,\"requiredStageIds\":[],"
              + "\"minScore\":null}"));
        assertThat(evaluator.evaluate(m, done()).complete()).isFalse();
        assertThat(evaluator.evaluate(m, done("a1", "a2", "b1")).complete())
                .isTrue();
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
        // 3 required activities total (a1,a2,b1) -> each ~33.3%
        SnapshotModel m = SnapshotModel.parse(
                snapshotWithCompletion("{\"minScore\":75}"));
        assertThat(evaluator.evaluate(m, done("a1", "a2", "b1")).complete()).isTrue();
        assertThat(evaluator.evaluate(m, done("a1", "a2")).complete()).isFalse();
    }

    @Test
    void combinedClauses_allMustHold() {
        SnapshotModel m = SnapshotModel.parse(snapshotWithCompletion(
                "{\"requireAllRequiredStages\":true,\"minScore\":50}"));
        // required stages done, 3/3 = 100% >= 50 -> complete
        assertThat(evaluator.evaluate(m, done("a1", "a2", "b1")).complete()).isTrue();
        // required stage s2 incomplete -> fail even though score might be ok
        LessonCompletion r = evaluator.evaluate(m, done("a1", "a2"));
        assertThat(r.complete()).isFalse();
    }

    @Test
    void detail_carriesCounts() {
        SnapshotModel m = SnapshotModel.parse(snapshot(null));
        LessonCompletion r = evaluator.evaluate(m, done("a1"));
        assertThat(r.detail().get("completedRequired").asInt()).isEqualTo(1);
        assertThat(r.detail().get("totalRequired").asInt()).isEqualTo(3);
    }
}
