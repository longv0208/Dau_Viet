package com.dauviet.learning.resolver;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.contract.NextStage;
import com.dauviet.learning.domain.AttemptState;
import com.dauviet.learning.domain.SnapshotInvalidForActivityException;
import com.dauviet.learning.snapshot.SnapshotModel;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

class StageTransitionResolverTest {

    private static final ObjectMapper OM = new ObjectMapper();
    private final StageTransitionResolver resolver = new StageTransitionResolver();

    private static JsonNode json(String s) {
        try { return OM.readTree(s); } catch (Exception e) { throw new IllegalStateException(e); }
    }

    /** Linear: ctx(READ optional, r-req required) -> ev(es required) -> []. */
    private static JsonNode linear() {
        return json("""
                {"stages":[
                  {"id":"ctx","type":"CONTEXT","required":true,
                   "activities":[
                     {"id":"opt","type":"READ"},
                     {"id":"rq","type":"READ","required":true}],
                   "nextStageIds":["ev"]},
                  {"id":"ev","type":"EVIDENCE","required":true,
                   "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true}],
                   "nextStageIds":[]}]}
                """);
    }

    private static AttemptState at(String stageId, String activityId) {
        AttemptState s = new AttemptState();
        s.setCurrentStageId(stageId);
        s.setCurrentActivityId(activityId);
        return s;
    }

    @Test
    void linear_sameStageNextRequired() {
        SnapshotModel m = SnapshotModel.parse(linear());
        AttemptState s = at("ctx", "opt");
        s.markCompleted("opt");   // optional done, required pending
        var t = resolver.resolve(m, s, "opt", ActivityResult.COMPLETED);
        assertThat(t.nextActivity()).isNotNull();
        assertThat(t.nextActivity().activityId()).isEqualTo("rq");
        assertThat(t.nextActivity().stageId()).isEqualTo("ctx");
    }

    @Test
    void linear_stageComplete_hopsForward() {
        SnapshotModel m = SnapshotModel.parse(linear());
        AttemptState s = at("ctx", "rq");
        s.markCompleted("rq");
        var t = resolver.resolve(m, s, "rq", ActivityResult.COMPLETED);
        assertThat(t.nextStage()).isNotNull();
        assertThat(t.nextStage().stageId()).isEqualTo("ev");
        assertThat(t.nextStage().reason()).isEqualTo(NextStage.FORWARD);
    }

    @Test
    void linear_allDone_returnsNull() {
        SnapshotModel m = SnapshotModel.parse(linear());
        AttemptState s = at("ev", "es");
        s.markCompleted("rq");
        s.markCompleted("es");
        var t = resolver.resolve(m, s, "es", ActivityResult.COMPLETED);
        assertThat(t).isNull();
    }

    @Test
    void optionalSubmit_doesNotGateAdvance() {
        // optional activity last in stage, required already done -> stage complete
        SnapshotModel m = SnapshotModel.parse(linear());
        AttemptState s = at("ctx", "rq");
        s.markCompleted("rq");
        // pretend current is an optional act after required — resolve should hop
        var t = resolver.resolve(m, s, "rq", ActivityResult.COMPLETED);
        assertThat(t.nextStage()).isNotNull();
    }

    @Test
    void nonLinear_firstIncompleteTargetChosen() {
        // A -> {B, C} -> D : B complete, C has work -> picks C over D
        JsonNode snap = json("""
                {"stages":[
                  {"id":"a","type":"CONTEXT","activities":[
                    {"id":"aq","type":"READ","required":true}],
                   "nextStageIds":["b","c"]},
                  {"id":"b","type":"EVIDENCE","activities":[
                    {"id":"bq","type":"READ","required":true}],
                   "nextStageIds":["d"]},
                  {"id":"c","type":"EVIDENCE","activities":[
                    {"id":"cq","type":"READ","required":true}],
                   "nextStageIds":["d"]},
                  {"id":"d","type":"CONCLUSION","activities":[
                    {"id":"dq","type":"READ","required":true}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel m = SnapshotModel.parse(snap);
        AttemptState s = at("a", "aq");
        s.markCompleted("aq");
        s.markCompleted("bq");   // B finished already (learner visited earlier)
        var t = resolver.resolve(m, s, "aq", ActivityResult.COMPLETED);
        assertThat(t.nextStage().stageId()).isEqualTo("c");
    }

    @Test
    void nonLinear_allTargetsDone_convergentFallback() {
        // all nextStageIds complete -> fall back to first incomplete in array order
        JsonNode snap = json("""
                {"stages":[
                  {"id":"a","type":"CONTEXT","activities":[
                    {"id":"aq","type":"READ","required":true}],
                   "nextStageIds":["b"]},
                  {"id":"b","type":"EVIDENCE","activities":[
                    {"id":"bq","type":"READ","required":true}],
                   "nextStageIds":[]},
                  {"id":"z","type":"CONCLUSION","activities":[
                    {"id":"zq","type":"READ","required":true}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel m = SnapshotModel.parse(snap);
        AttemptState s = at("a", "aq");
        s.markCompleted("aq");
        s.markCompleted("bq");   // the only nextStageIds target is done
        var t = resolver.resolve(m, s, "aq", ActivityResult.COMPLETED);
        assertThat(t.nextStage().stageId()).isEqualTo("z");
        assertThat(t.nextStage().reason()).isEqualTo(NextStage.FORWARD);
    }

    @Test
    void revision_partialOutcome_onPartialTarget() {
        JsonNode snap = json("""
                {"stages":[
                  {"id":"hyp","type":"HYPOTHESIS","activities":[
                    {"id":"hc","type":"HYPOTHESIS_CHOICE","required":true}],
                   "nextStageIds":[]},
                  {"id":"ver","type":"VERIFICATION","activities":[
                    {"id":"vf","type":"VERIFICATION","required":true,
                     "onPartial":"hyp","onContradicted":"hyp"}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel m = SnapshotModel.parse(snap);
        AttemptState s = at("ver", "vf");
        var t = resolver.resolve(m, s, "vf", ActivityResult.PARTIAL);
        assertThat(t.nextStage()).isNotNull();
        assertThat(t.nextStage().stageId()).isEqualTo("hyp");
        assertThat(t.nextStage().reason()).isEqualTo(NextStage.REVISE);
    }

    @Test
    void revision_missingTarget_incompleteRequired_staysNotForward() {
        // onPartial points at a stage that doesn't exist -> hop can't fire;
        // required activity still incomplete -> cursor stays (TASK-0011 fix:
        // previously this fell through to forward advance and soft-locked).
        JsonNode snap = json("""
                {"stages":[
                  {"id":"ver","type":"VERIFICATION","activities":[
                    {"id":"vf","type":"VERIFICATION","required":true,
                     "onPartial":"ghost"}],
                   "nextStageIds":["end"]},
                  {"id":"end","type":"CONCLUSION","activities":[
                    {"id":"cer","type":"CER","required":true}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel m = SnapshotModel.parse(snap);
        AttemptState s = at("ver", "vf");
        var t = resolver.resolve(m, s, "vf", ActivityResult.PARTIAL);
        assertThat(t.nextActivity()).isNotNull();
        assertThat(t.nextActivity().activityId()).isEqualTo("vf");
        assertThat(t.nextActivity().stageId()).isEqualTo("ver");
    }

    @Test
    void revision_missingTarget_completedRequired_fallsThroughToForward() {
        // same shape but activity already completed -> normal forward walk
        JsonNode snap = json("""
                {"stages":[
                  {"id":"ver","type":"VERIFICATION","activities":[
                    {"id":"vf","type":"VERIFICATION","required":true,
                     "onPartial":"ghost"}],
                   "nextStageIds":["end"]},
                  {"id":"end","type":"CONCLUSION","activities":[
                    {"id":"cer","type":"CER","required":true}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel m = SnapshotModel.parse(snap);
        AttemptState s = at("ver", "vf");
        s.markCompleted("vf");
        var t = resolver.resolve(m, s, "vf", ActivityResult.PARTIAL);
        assertThat(t.nextStage().stageId()).isEqualTo("end");
        assertThat(t.nextStage().reason()).isEqualTo(NextStage.FORWARD);
    }

    @Test
    void cyclicSnapshot_guarded_noInfiniteLoop() {
        // hand-edited cycle: publish validator would reject, but resolver must not loop
        JsonNode snap = json("""
                {"stages":[
                  {"id":"a","type":"CONTEXT","activities":[
                    {"id":"aq","type":"READ","required":true}],
                   "nextStageIds":["b"]},
                  {"id":"b","type":"EVIDENCE","activities":[
                    {"id":"bq","type":"READ","required":true}],
                   "nextStageIds":["a"]}]}
                """);
        SnapshotModel m = SnapshotModel.parse(snap);
        AttemptState s = at("a", "aq");
        s.markCompleted("aq");
        // b incomplete -> picks b, no loop. Then completing b with cursor b
        // walks b->a (all complete) then falls back to null.
        var t1 = resolver.resolve(m, s, "aq", ActivityResult.COMPLETED);
        assertThat(t1.nextStage().stageId()).isEqualTo("b");

        AttemptState s2 = at("b", "bq");
        s2.markCompleted("aq");
        s2.markCompleted("bq");
        var t2 = resolver.resolve(m, s2, "bq", ActivityResult.COMPLETED);
        assertThat(t2).isNull();
    }

    /* ---- step (0): incomplete required keeps cursor (TASK-0011 fixes) ---- */

    @Test
    void requiredIncomplete_staysOnSameActivity() {
        SnapshotModel m = SnapshotModel.parse(linear());
        AttemptState s = at("ctx", "rq");
        // rq required, not completed -> resolver must NOT advance past it
        var t = resolver.resolve(m, s, "rq", ActivityResult.INCORRECT);
        assertThat(t.nextActivity()).isNotNull();
        assertThat(t.nextActivity().stageId()).isEqualTo("ctx");
        assertThat(t.nextActivity().activityId()).isEqualTo("rq");
    }

    @Test
    void requiredIncomplete_partial_outcomeDrivenHopWins() {
        // VERIFICATION-style required act with onPartial -> REVISE hop beats stay
        JsonNode snap = json("""
                {"stages":[
                  {"id":"hyp","type":"HYPOTHESIS","activities":[
                    {"id":"hc","type":"HYPOTHESIS_CHOICE","required":true}],
                   "nextStageIds":[]},
                  {"id":"ver","type":"VERIFICATION","activities":[
                    {"id":"vf","type":"VERIFICATION","required":true,
                     "onPartial":"hyp","onContradicted":"hyp"}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel m = SnapshotModel.parse(snap);
        AttemptState s = at("ver", "vf");
        var t = resolver.resolve(m, s, "vf", ActivityResult.PARTIAL);
        assertThat(t.nextStage()).isNotNull();
        assertThat(t.nextStage().stageId()).isEqualTo("hyp");
        assertThat(t.nextStage().reason()).isEqualTo(NextStage.REVISE);
    }

    @Test
    void requiredIncomplete_noHopTarget_stays() {
        JsonNode snap = json("""
                {"stages":[
                  {"id":"ver","type":"VERIFICATION","activities":[
                    {"id":"vf","type":"VERIFICATION","required":true,
                     "onPartial":"ghost"}],
                   "nextStageIds":["end"]},
                  {"id":"end","type":"CONCLUSION","activities":[
                    {"id":"cer","type":"CER","required":true}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel m = SnapshotModel.parse(snap);
        AttemptState s = at("ver", "vf");
        var t = resolver.resolve(m, s, "vf", ActivityResult.PARTIAL);
        assertThat(t.nextActivity()).isNotNull();
        assertThat(t.nextActivity().activityId()).isEqualTo("vf");
        assertThat(t.nextActivity().stageId()).isEqualTo("ver");
    }

    @Test
    void optionalIncomplete_stillAdvances() {
        SnapshotModel m = SnapshotModel.parse(linear());
        AttemptState s = at("ctx", "opt");
        // optional "opt" not completed — never blocks; next required is rq
        var t = resolver.resolve(m, s, "opt", ActivityResult.IN_PROGRESS);
        assertThat(t.nextActivity()).isNotNull();
        assertThat(t.nextActivity().activityId()).isEqualTo("rq");
    }

    @Test
    void exhausted_completedRequired_advances() {
        // retry budget spent -> handler reported completed -> advance normally
        SnapshotModel m = SnapshotModel.parse(linear());
        AttemptState s = at("ctx", "rq");
        s.markCompleted("rq");
        var t = resolver.resolve(m, s, "rq", ActivityResult.INCORRECT);
        assertThat(t.nextStage()).isNotNull();
        assertThat(t.nextStage().stageId()).isEqualTo("ev");
    }

    @Test
    void requiredFreeStageTraversed_transparently() {
        // stage with NO required activities sits between two real stages
        JsonNode snap = json("""
                {"stages":[
                  {"id":"a","type":"CONTEXT","activities":[
                    {"id":"aq","type":"READ","required":true}],
                   "nextStageIds":["mid"]},
                  {"id":"mid","type":"CONTEXT","activities":[
                    {"id":"opt","type":"READ"}],
                   "nextStageIds":["b"]},
                  {"id":"b","type":"EVIDENCE","activities":[
                    {"id":"bq","type":"READ","required":true}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel m = SnapshotModel.parse(snap);
        AttemptState s = at("a", "aq");
        s.markCompleted("aq");
        var t = resolver.resolve(m, s, "aq", ActivityResult.COMPLETED);
        // mid is required-free -> transparent -> traversed through to b
        assertThat(t.nextStage().stageId()).isEqualTo("b");
    }
}
