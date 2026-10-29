package com.dauviet.learning.handler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.LinkedHashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.handler.ScoredHandlers.DragOrderHandler;
import com.dauviet.learning.handler.ScoredHandlers.MatchingHandler;
import com.dauviet.learning.handler.ScoredHandlers.MultipleChoiceHandler;
import com.fasterxml.jackson.databind.JsonNode;

class ScoredHandlersTest {

    private final MultipleChoiceHandler mcq = new MultipleChoiceHandler();
    private final MatchingHandler matching = new MatchingHandler();
    private final DragOrderHandler dragOrder = new DragOrderHandler();

    private static JsonNode snapshot() {
        return HandlerTestSupport.json(
                "{\"stages\":[{\"id\":\"s1\",\"type\":\"EVIDENCE\",\"activities\":[]}]}");
    }

    private static JsonNode mcActivity(int maxAttempts) {
        return HandlerTestSupport.json(
                "{\"id\":\"mc\",\"type\":\"MULTIPLE_CHOICE\",\"config\":{"
              + "\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"},{\"id\":\"o3\"}],"
              + "\"correctOptionIds\":[\"o1\",\"o2\"]"
              + (maxAttempts > 0 ? ",\"maxAttempts\":" + maxAttempts : "") + "}}");
    }

    @Test
    void mcq_exactSetMatch_completedCorrect() {
        ActivityResult r = mcq.evaluate(
                HandlerTestSupport.ctx(mcActivity(0), snapshot()),
                HandlerTestSupport.sub("mc", "{\"selectedOptionIds\":[\"o2\",\"o1\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.COMPLETED);
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("correct").asBoolean()).isTrue();
        // never echoes answer key
        assertThat(r.output().has("correctOptionIds")).isFalse();
    }

    @Test
    void mcq_wrongSet_incorrect_notCompleted() {
        ActivityResult r = mcq.evaluate(
                HandlerTestSupport.ctx(mcActivity(3), snapshot()),
                HandlerTestSupport.sub("mc", "{\"selectedOptionIds\":[\"o1\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("correct").asBoolean()).isFalse();
        assertThat(r.output().has("exhausted")).isFalse();
    }

    @Test
    void mcq_maxAttemptsReached_exhausted_completes() {
        // maxAttempts=2, this is attempt #2 -> exhausted even though wrong
        Map<String, JsonNode> prior = new LinkedHashMap<>();
        prior.put("mc", HandlerTestSupport.json("{\"attemptCount\":1}"));
        ActivityResult r = mcq.evaluate(
                HandlerTestSupport.ctx(mcActivity(2), snapshot(), prior),
                HandlerTestSupport.sub("mc", "{\"selectedOptionIds\":[\"o3\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
        assertThat(r.completed()).isTrue();   // exhausted -> activity gates done
        assertThat(r.output().get("exhausted").asBoolean()).isTrue();
        assertThat(r.output().get("attemptCount").asInt()).isEqualTo(2);
    }

    @Test
    void mcq_multiCorrectLegacy_gradesCorrectly() {
        // Legacy drafts authored multi-answer via multiCorrect — the handler
        // must grade it identically to canonical correctOptionIds.
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"mc\",\"type\":\"MULTIPLE_CHOICE\",\"config\":{"
              + "\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"},{\"id\":\"o3\"}],"
              + "\"multiCorrect\":[\"o1\",\"o3\"],\"multiSelect\":true}}");
        ActivityResult r = mcq.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("mc", "{\"selectedOptionIds\":[\"o3\",\"o1\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.COMPLETED);
        assertThat(r.output().get("correct").asBoolean()).isTrue();
        assertThat(r.output().has("multiCorrect")).isFalse();
    }

    @Test
    void mcq_multiCorrectLegacy_wrongSet_incorrect() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"mc\",\"type\":\"MULTIPLE_CHOICE\",\"config\":{"
              + "\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"},{\"id\":\"o3\"}],"
              + "\"multiCorrect\":[\"o1\",\"o3\"]}}");
        ActivityResult r = mcq.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("mc", "{\"selectedOptionIds\":[\"o1\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
        assertThat(r.output().get("correct").asBoolean()).isFalse();
    }

    @Test
    void mcq_undeclaredOption_rejected() {
        assertThatThrownBy(() -> mcq.evaluate(
                HandlerTestSupport.ctx(mcActivity(0), snapshot()),
                HandlerTestSupport.sub("mc", "{\"selectedOptionIds\":[\"o9\"]}")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("option");
    }

    @Test
    void matching_correctPairSet_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"mt\",\"type\":\"MATCHING\",\"config\":{"
              + "\"pairs\":[{\"left\":{\"id\":\"l1\"},\"right\":{\"id\":\"r1\"}},"
              + "            {\"left\":{\"id\":\"l2\"},\"right\":{\"id\":\"r2\"}}],"
              + "\"correctPairs\":[{\"left\":\"l1\",\"right\":\"r2\"},"
              + "                 {\"left\":\"l2\",\"right\":\"r1\"}]}}");
        ActivityResult r = matching.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("mt",
                        "{\"pairs\":[{\"leftId\":\"l2\",\"rightId\":\"r1\"},"
                        + "          {\"leftId\":\"l1\",\"rightId\":\"r2\"}]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().has("correctPairs")).isFalse();
    }

    @Test
    void matching_wrongPairs_incorrect() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"mt\",\"type\":\"MATCHING\",\"config\":{"
              + "\"pairs\":[{\"left\":{\"id\":\"l1\"},\"right\":{\"id\":\"r1\"}},"
              + "            {\"left\":{\"id\":\"l2\"},\"right\":{\"id\":\"r2\"}}],"
              + "\"correctPairs\":[{\"left\":\"l1\",\"right\":\"r1\"},"
              + "                 {\"left\":\"l2\",\"right\":\"r2\"}]}}");
        ActivityResult r = matching.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("mt",
                        "{\"pairs\":[{\"leftId\":\"l1\",\"rightId\":\"r2\"},"
                        + "          {\"leftId\":\"l2\",\"rightId\":\"r1\"}]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
        assertThat(r.completed()).isFalse();
    }

    @Test
    void dragOrder_exactOrder_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"do\",\"type\":\"DRAG_ORDER\",\"config\":{"
              + "\"items\":[{\"id\":\"i1\"},{\"id\":\"i2\"},{\"id\":\"i3\"}],"
              + "\"expectedOrder\":[\"i3\",\"i1\",\"i2\"]}}");
        ActivityResult r = dragOrder.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("do", "{\"orderedIds\":[\"i3\",\"i1\",\"i2\"]}"));
        assertThat(r.completed()).isTrue();
        assertThat(r.output().has("expectedOrder")).isFalse();
    }

    @Test
    void dragOrder_alternateAcceptedSequence_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"do\",\"type\":\"DRAG_ORDER\",\"config\":{"
              + "\"items\":[{\"id\":\"i1\"},{\"id\":\"i2\"},{\"id\":\"i3\"}],"
              + "\"expectedOrder\":[\"i1\",\"i2\",\"i3\"],"
              + "\"acceptedSequences\":[[\"i3\",\"i2\",\"i1\"]]}}");
        ActivityResult r = dragOrder.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("do", "{\"orderedIds\":[\"i3\",\"i2\",\"i1\"]}"));
        assertThat(r.completed()).isTrue();
    }

    @Test
    void dragOrder_wrongOrder_incorrect() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"do\",\"type\":\"DRAG_ORDER\",\"config\":{"
              + "\"items\":[{\"id\":\"i1\"},{\"id\":\"i2\"}],"
              + "\"expectedOrder\":[\"i1\",\"i2\"]}}");
        ActivityResult r = dragOrder.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("do", "{\"orderedIds\":[\"i2\",\"i1\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
    }

    @Test
    void matching_partialPairs_partial_notCompleted() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"mt\",\"type\":\"MATCHING\",\"config\":{"
              + "\"pairs\":[{\"left\":{\"id\":\"l1\"},\"right\":{\"id\":\"r1\"}},"
              + "            {\"left\":{\"id\":\"l2\"},\"right\":{\"id\":\"r2\"}}],"
              + "\"correctPairs\":[{\"left\":\"l1\",\"right\":\"r1\"},"
              + "                 {\"left\":\"l2\",\"right\":\"r2\"}],"
              + "\"maxAttempts\":3}}");
        ActivityResult r = matching.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("mt",
                        "{\"pairs\":[{\"leftId\":\"l1\",\"rightId\":\"r1\"},"
                        + "          {\"leftId\":\"l2\",\"rightId\":\"r1\"}]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.PARTIAL);
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("matchedCount").asInt()).isEqualTo(1);
        assertThat(r.output().get("correctPositions").asInt()).isEqualTo(1);
        assertThat(r.output().get("totalItems").asInt()).isEqualTo(2);
        assertThat(r.output().get("attemptCount").asInt()).isEqualTo(1);
    }

    @Test
    void matching_maxAttemptsReached_exhausted_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"mt\",\"type\":\"MATCHING\",\"config\":{"
              + "\"pairs\":[{\"left\":{\"id\":\"l1\"},\"right\":{\"id\":\"r1\"}},"
              + "            {\"left\":{\"id\":\"l2\"},\"right\":{\"id\":\"r2\"}}],"
              + "\"correctPairs\":[{\"left\":\"l1\",\"right\":\"r1\"},"
              + "                 {\"left\":\"l2\",\"right\":\"r2\"}],"
              + "\"maxAttempts\":1}}");
        ActivityResult r = matching.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("mt",
                        "{\"pairs\":[{\"leftId\":\"l1\",\"rightId\":\"r2\"},"
                        + "          {\"leftId\":\"l2\",\"rightId\":\"r1\"}]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("exhausted").asBoolean()).isTrue();
    }

    @Test
    void dragOrder_halfPositions_partial() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"do\",\"type\":\"DRAG_ORDER\",\"config\":{"
              + "\"items\":[{\"id\":\"i1\"},{\"id\":\"i2\"},{\"id\":\"i3\"},{\"id\":\"i4\"}],"
              + "\"expectedOrder\":[\"i1\",\"i2\",\"i3\",\"i4\"],"
              + "\"maxAttempts\":3}}");
        ActivityResult r = dragOrder.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("do",
                        "{\"orderedIds\":[\"i1\",\"i2\",\"i4\",\"i3\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.PARTIAL);
        assertThat(r.completed()).isFalse();
        assertThat(r.output().get("correctPositions").asInt()).isEqualTo(2);
        assertThat(r.output().get("totalItems").asInt()).isEqualTo(4);
        assertThat(r.output().has("expectedOrder")).isFalse();
    }

    @Test
    void dragOrder_belowHalf_incorrect() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"do\",\"type\":\"DRAG_ORDER\",\"config\":{"
              + "\"items\":[{\"id\":\"i1\"},{\"id\":\"i2\"},{\"id\":\"i3\"},{\"id\":\"i4\"}],"
              + "\"expectedOrder\":[\"i1\",\"i2\",\"i3\",\"i4\"],"
              + "\"maxAttempts\":3}}");
        ActivityResult r = dragOrder.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("do",
                        "{\"orderedIds\":[\"i4\",\"i3\",\"i2\",\"i1\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
        assertThat(r.output().get("correctPositions").asInt()).isEqualTo(0);
    }

    @Test
    void dragOrder_maxAttemptsReached_exhausted_completes() {
        JsonNode act = HandlerTestSupport.json(
                "{\"id\":\"do\",\"type\":\"DRAG_ORDER\",\"config\":{"
              + "\"items\":[{\"id\":\"i1\"},{\"id\":\"i2\"}],"
              + "\"expectedOrder\":[\"i1\",\"i2\"],"
              + "\"maxAttempts\":1}}");
        ActivityResult r = dragOrder.evaluate(
                HandlerTestSupport.ctx(act, snapshot()),
                HandlerTestSupport.sub("do",
                        "{\"orderedIds\":[\"i2\",\"i1\"]}"));
        assertThat(r.outcome()).isEqualTo(ActivityResult.INCORRECT);
        assertThat(r.completed()).isTrue();
        assertThat(r.output().get("exhausted").asBoolean()).isTrue();
    }
}
