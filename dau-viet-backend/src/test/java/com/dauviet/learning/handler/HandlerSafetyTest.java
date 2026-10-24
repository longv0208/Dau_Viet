package com.dauviet.learning.handler;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.junit.jupiter.api.Test;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.contract.ActivitySubmission;
import com.dauviet.learning.contract.AttemptContext;
import com.dauviet.lesson.draft.DraftSchema;
import com.fasterxml.jackson.databind.JsonNode;

/**
 * For every registered handler: craft a submission whose free-text fields
 * contain hidden-key strings (e.g. "correctOptionIds") and assert the emitted
 * ActivityResult carries zero LEARNER_HIDDEN_KEYS leaf names anywhere in
 * output — stripping is by leaf name, not substring, so the submitted text
 * itself must survive.
 */
class HandlerSafetyTest {

    private final ActivityHandlerRegistry registry = new ActivityHandlerRegistry(
            List.of(
                    new AcknowledgmentHandlers.ReadHandler(),
                    new AcknowledgmentHandlers.ViewImageHandler(),
                    new AcknowledgmentHandlers.ReflectionPromptHandler(),
                    new ExploreMapHandler(),
                    new SelectionHandlers.EvidenceSelectHandler(),
                    new SelectionHandlers.HypothesisChoiceHandler(),
                    new ScoredHandlers.MultipleChoiceHandler(),
                    new ScoredHandlers.MatchingHandler(),
                    new ScoredHandlers.DragOrderHandler(),
                    new ReasoningHandlers.ReasoningConnectHandler(),
                    new ReasoningHandlers.VerificationHandler(),
                    new ReasoningHandlers.CerHandler(),
                    new CerChoiceHandler()));

    private static JsonNode activity(String type, String config) {
        return HandlerTestSupport.json(
                "{\"id\":\"a1\",\"type\":\"" + type + "\",\"config\":" + config + "}");
    }

    private static JsonNode snapshot() {
        return HandlerTestSupport.json(
                "{\"stages\":[{\"id\":\"s1\",\"type\":\"EVIDENCE\",\"activities\":[]}],"
              + "\"evidence\":[{\"id\":\"e1\"},{\"id\":\"e2\"}],"
              + "\"assets\":[{\"id\":\"a9\"}]}");
    }

    /** Valid answer per type, with hidden-key strings embedded in free text. */
    private static final Map<String, List<Object[]>> CASES = Map.ofEntries(
            Map.entry("READ", List.of(new Object[][]{
                    {activity("READ", "{\"text\":\"t\"}"),
                            "{\"note\":\"correctOptionIds\"}"}})),
            Map.entry("VIEW_IMAGE", List.of(new Object[][]{
                    {activity("VIEW_IMAGE", "{\"imageAssetId\":\"a9\"}"), "{}"}})),
            Map.entry("REFLECTION_PROMPT", List.of(new Object[][]{
                    {activity("REFLECTION_PROMPT", "{\"prompt\":\"p\"}"),
                            "{\"text\":\"expectedOrder answerKey expected\"}"}})),
            Map.entry("EXPLORE_MAP", List.of(new Object[][]{
                    {activity("EXPLORE_MAP", "{\"markers\":[{\"id\":\"m1\"}]}"),
                            "{\"markerId\":\"m1\"}"}})),
            Map.entry("EVIDENCE_SELECT", List.of(new Object[][]{
                    {activity("EVIDENCE_SELECT",
                            "{\"visibleEvidenceIds\":[\"e1\",\"e2\"]}"),
                            "{\"selectedEvidenceIds\":[\"e1\"]}"}})),
            Map.entry("HYPOTHESIS_CHOICE", List.of(new Object[][]{
                    {activity("HYPOTHESIS_CHOICE",
                            "{\"hypotheses\":[{\"id\":\"h1\"},{\"id\":\"h2\"}]}"),
                            "{\"hypothesisId\":\"h1\",\"evidenceIds\":[\"e1\"]}"}})),
            Map.entry("MULTIPLE_CHOICE", List.of(new Object[][]{
                    {activity("MULTIPLE_CHOICE",
                            "{\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
                            + "\"correctOptionIds\":[\"o1\"]}"),
                            "{\"selectedOptionIds\":[\"o1\"]}"}})),
            Map.entry("MATCHING", List.of(new Object[][]{
                    {activity("MATCHING",
                            "{\"pairs\":[{\"left\":{\"id\":\"l1\"},\"right\":{\"id\":\"r1\"}},"
                            + "{\"left\":{\"id\":\"l2\"},\"right\":{\"id\":\"r2\"}}],"
                            + "\"correctPairs\":[{\"left\":\"l1\",\"right\":\"r1\"},"
                            + "{\"left\":\"l2\",\"right\":\"r2\"}]}"),
                            "{\"pairs\":[{\"leftId\":\"l1\",\"rightId\":\"r1\"},"
                            + "{\"leftId\":\"l2\",\"rightId\":\"r2\"}]}"}})),
            Map.entry("DRAG_ORDER", List.of(new Object[][]{
                    {activity("DRAG_ORDER",
                            "{\"items\":[{\"id\":\"i1\"},{\"id\":\"i2\"}],"
                            + "\"expectedOrder\":[\"i1\",\"i2\"]}"),
                            "{\"orderedIds\":[\"i1\",\"i2\"]}"}})),
            Map.entry("REASONING_CONNECT", List.of(new Object[][]{
                    {activity("REASONING_CONNECT",
                            "{\"nodes\":[{\"id\":\"n1\"},{\"id\":\"n2\"}],"
                            + "\"allowedRelations\":[\"causes\"]}"),
                            "{\"relations\":[{\"from\":\"n1\",\"to\":\"n2\","
                            + "\"relation\":\"causes\"}]}"}})),
            Map.entry("VERIFICATION", List.of(new Object[][]{
                    {activity("VERIFICATION", "{\"requiredEvidenceIds\":[\"e1\"]}"),
                            "{\"acknowledged\":true}"}})),
            Map.entry("CER", List.of(new Object[][]{
                    {activity("CER",
                            "{\"rubric\":{\"criteria\":[\"c\"]},"
                            + "\"requiredEvidenceIds\":[\"e1\"]}"),
                            "{\"claim\":\"claim text about correctOptionIds keys\","
                            + "\"reasoning\":\"reasoning long enough to pass\"}"}})),
            Map.entry("CER_CHOICE", List.of(new Object[][]{
                    {activity("CER_CHOICE",
                            "{\"claims\":[{\"id\":\"c1\"},{\"id\":\"c2\"}],"
                            + "\"reasoningOptions\":[{\"id\":\"r1\"},{\"id\":\"r2\"}],"
                            + "\"evidenceOptions\":[{\"id\":\"e1\"}],"
                            + "\"acceptedClaims\":[\"c1\"],"
                            + "\"acceptedEvidenceIds\":[\"e1\"],"
                            + "\"acceptedReasoningIds\":[\"r1\"]}"),
                            "{\"claimId\":\"c1\",\"evidenceIds\":[\"e1\"],"
                            + "\"reasoningId\":\"r1\"}"}})));

    @Test
    void everyHandler_emitsNoHiddenKeys() {
        for (var entry : CASES.entrySet()) {
            String type = entry.getKey();
            ActivityHandler handler = registry.handlerFor(
                    com.dauviet.lesson.draft.ActivityType.valueOf(type));
            for (Object[] c : entry.getValue()) {
                JsonNode activity = (JsonNode) c[0];
                JsonNode answer = HandlerTestSupport.json((String) c[1]);
                // VERIFICATION needs a prior hypothesis to reach SUPPORTED; the
                // CONTRADICTED path still exercises output construction.
                Map<String, JsonNode> prior = new LinkedHashMap<>();
                if ("VERIFICATION".equals(type)) {
                    prior.put("hc", HandlerTestSupport.json(
                            "{\"hypothesisId\":\"h1\",\"evidenceIds\":[\"e1\"]}"));
                }
                AttemptContext ctx = new AttemptContext(
                        java.util.UUID.randomUUID(), java.util.UUID.randomUUID(),
                        java.util.UUID.randomUUID(), "s1", "a1",
                        activity, snapshot(), prior);
                ActivityResult result = handler.evaluate(ctx,
                        new ActivitySubmission(ctx.attemptId(), "a1", answer, null));
                assertHiddenKeysAbsent(result.output(), type);
            }
        }
    }

    @Test
    void hiddenKeyStrings_inFreeText_surviveOutput() {
        // Sanitization is leaf-name based: a reflection text literally
        // containing "correctOptionIds" must be preserved in output.text.
        var handler = new AcknowledgmentHandlers.ReflectionPromptHandler();
        AttemptContext ctx = new AttemptContext(
                java.util.UUID.randomUUID(), java.util.UUID.randomUUID(),
                java.util.UUID.randomUUID(), "s1", "a1",
                activity("REFLECTION_PROMPT", "{\"prompt\":\"p\"}"), snapshot(),
                Map.of());
        ActivityResult r = handler.evaluate(ctx, new ActivitySubmission(
                ctx.attemptId(), "a1",
                HandlerTestSupport.json("{\"text\":\"mention correctOptionIds here\"}"), null));
        assertThat(r.output().get("text").asText()).contains("correctOptionIds");
    }

    private void assertHiddenKeysAbsent(JsonNode node, String type) {
        List<String> found = new ArrayList<>();
        collectHidden(node, found);
        assertThat(found).as("hidden keys in %s output", type).isEmpty();
    }

    private void collectHidden(JsonNode node, List<String> found) {
        if (node == null) return;
        if (node.isObject()) {
            node.fields().forEachRemaining(e -> {
                if (DraftSchema.LEARNER_HIDDEN_KEYS.contains(e.getKey())) {
                    found.add(e.getKey());
                }
                collectHidden(e.getValue(), found);
            });
        } else if (node.isArray()) {
            node.forEach(n -> collectHidden(n, found));
        }
    }

    @Test
    void registryCoversAllTypes_noDuplicate() {
        for (var t : com.dauviet.lesson.draft.ActivityType.values()) {
            assertThat(registry.handlerFor(t).supports()).isEqualTo(t);
        }
    }

    private static final Set<String> ALL = CASES.keySet();
}
