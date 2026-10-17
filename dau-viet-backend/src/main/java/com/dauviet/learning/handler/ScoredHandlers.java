package com.dauviet.learning.handler;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import org.springframework.stereotype.Component;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.contract.ActivitySubmission;
import com.dauviet.learning.contract.AttemptContext;
import com.dauviet.lesson.draft.ActivityType;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Server-side correctness activities. Each reads hidden answer keys from the
 * pinned snapshot for grading, but emitted output only ever reports
 * correct:bool + counts — never the keys themselves.
 * Retry budget: config.maxAttempts (default 1); exceeded -> INCORRECT +
 * exhausted:true. Attempt count derives from priorOutputs attemptCount.
 */
public final class ScoredHandlers {

    private ScoredHandlers() {
    }

    private static int priorAttempts(AttemptContext ctx) {
        JsonNode prior = ctx.priorOutputs().get(ctx.activityId());
        return prior != null && prior.isObject()
                ? prior.path("attemptCount").asInt(0) : 0;
    }

    @Component
    public static class MultipleChoiceHandler extends AbstractActivityHandler {
        @Override public ActivityType supports() { return ActivityType.MULTIPLE_CHOICE; }

        @Override
        public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
            JsonNode config = requireConfig(ctx.activity());
            Set<String> selected = new LinkedHashSet<>(readIdList(sub.answer(), "selectedOptionIds"));
            Set<String> valid = objectIds(config, "options");
            for (String id : selected) {
                if (!valid.contains(id)) {
                    throw new IllegalArgumentException("option '" + id + "' is not a declared option");
                }
            }
            int maxAttempts = config.path("maxAttempts").asInt(1);
            int attemptNo = priorAttempts(ctx) + 1;
            // Canonical key is correctOptionIds; legacy drafts used
            // multiCorrect for the multi-answer mode — grade both identically.
            Set<String> correct = stringIds(config.get("correctOptionIds"));
            if (correct.isEmpty()) {
                correct = stringIds(config.get("multiCorrect"));
            }
            boolean right = !correct.isEmpty() && selected.equals(correct);
            boolean exhausted = !right && attemptNo >= maxAttempts;
            boolean done = right || exhausted;

            JsonNodeFactory f = JsonNodeFactory.instance;
            ObjectNode out = f.objectNode();
            out.put("correct", right);
            out.put("selectedCount", selected.size());
            out.put("attemptCount", attemptNo);
            if (exhausted) out.put("exhausted", true);
            String outcome = right ? ActivityResult.COMPLETED : ActivityResult.INCORRECT;
            return result(outcome, done, out,
                    feedbackFor(ctx.activity(), right ? ActivityResult.COMPLETED
                            : exhausted ? "EXHAUSTED" : ActivityResult.INCORRECT));
        }
    }

    @Component
    public static class MatchingHandler extends AbstractActivityHandler {
        @Override public ActivityType supports() { return ActivityType.MATCHING; }

        @Override
        public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
            JsonNode config = requireConfig(ctx.activity());
            JsonNode pairs = requireArray(sub.answer(), "pairs");
            Set<String> leftIds = new LinkedHashSet<>();
            Set<String> rightIds = new LinkedHashSet<>();
            JsonNode declared = config.get("pairs");
            if (declared != null && declared.isArray()) {
                for (JsonNode p : declared) {
                    JsonNode l = p.path("left").path("id");
                    JsonNode r = p.path("right").path("id");
                    if (l.isTextual()) leftIds.add(l.asText());
                    if (r.isTextual()) rightIds.add(r.asText());
                }
            }
            Set<String> submitted = new LinkedHashSet<>();
            for (JsonNode p : pairs) {
                String l = p.path("leftId").asText(null);
                String r = p.path("rightId").asText(null);
                if (l == null || r == null
                        || !leftIds.contains(l) || !rightIds.contains(r)) {
                    throw new IllegalArgumentException("pair references undeclared ids");
                }
                submitted.add(l + "=" + r);
            }
            Set<String> expected = new LinkedHashSet<>();
            JsonNode correct = config.get("correctPairs");
            if (correct != null && correct.isArray()) {
                for (JsonNode cp : correct) {
                    String l = cp.path("left").asText(null);
                    String r = cp.path("right").asText(null);
                    if (l != null && r != null) expected.add(l + "=" + r);
                }
            }
            boolean right = !expected.isEmpty() && submitted.equals(expected);
            JsonNodeFactory f = JsonNodeFactory.instance;
            ObjectNode out = f.objectNode();
            out.put("correct", right);
            out.put("matchedCount", submitted.size());
            String outcome = right ? ActivityResult.COMPLETED : ActivityResult.INCORRECT;
            return result(outcome, right, out,
                    feedbackFor(ctx.activity(), outcome));
        }
    }

    @Component
    public static class DragOrderHandler extends AbstractActivityHandler {
        @Override public ActivityType supports() { return ActivityType.DRAG_ORDER; }

        @Override
        public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
            JsonNode config = requireConfig(ctx.activity());
            List<String> ordered = readIdList(sub.answer(), "orderedIds");
            Set<String> itemIds = objectIds(config, "items");
            for (String id : ordered) {
                if (!itemIds.contains(id)) {
                    throw new IllegalArgumentException("id '" + id + "' is not a declared item");
                }
            }
            List<String> expected = config.has("expectedOrder")
                    ? toList(config.get("expectedOrder"))
                    : toList(config.get("correctOrder"));
            Set<List<String>> accepted = new LinkedHashSet<>();
            if (!expected.isEmpty()) accepted.add(expected);
            JsonNode extra = config.get("acceptedSequences");
            if (extra != null && extra.isArray()) {
                for (JsonNode seq : extra) accepted.add(toList(seq));
            }
            boolean right = !accepted.isEmpty() && accepted.contains(ordered);
            JsonNodeFactory f = JsonNodeFactory.instance;
            ObjectNode out = f.objectNode();
            out.put("correct", right);
            String outcome = right ? ActivityResult.COMPLETED : ActivityResult.INCORRECT;
            return result(outcome, right, out,
                    feedbackFor(ctx.activity(), outcome));
        }

        private List<String> toList(JsonNode array) {
            List<String> out = new java.util.ArrayList<>();
            if (array != null && array.isArray()) {
                array.forEach(n -> { if (n.isTextual()) out.add(n.asText()); });
            }
            return out;
        }
    }
}
