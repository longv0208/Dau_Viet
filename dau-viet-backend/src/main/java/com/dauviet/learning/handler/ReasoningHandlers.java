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
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Reasoning/verification activities.
 * VERIFICATION grades the recorded HYPOTHESIS_CHOICE output against the
 * server-only config.requiredEvidenceIds (+ expectedHypothesis when authored):
 *   SUPPORTED    = hypothesis chosen AND every required evidence id present;
 *   PARTIAL      = hypothesis chosen but required evidence incomplete;
 *   CONTRADICTED = no hypothesis on record, or expectedHypothesis authored
 *                  and the chosen hypothesis differs.
 * REVISE answer ({revise:true}) re-reads prior outputs the same way — the
 * transition resolver maps the outcome via onPartial/onContradicted.
 */
public final class ReasoningHandlers {

    private ReasoningHandlers() {
    }

    @Component
    public static class ReasoningConnectHandler extends AbstractActivityHandler {
        @Override public ActivityType supports() { return ActivityType.REASONING_CONNECT; }

        @Override
        public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
            JsonNode config = requireConfig(ctx.activity());
            Set<String> nodeIds = objectIds(config, "nodes");
            Set<String> allowed = stringIds(config.get("allowedRelations"));
            JsonNode relations = requireArray(sub.answer(), "relations");
            for (JsonNode rel : relations) {
                String from = rel.path("from").asText(null);
                String to = rel.path("to").asText(null);
                String name = rel.path("relation").asText(null);
                if (from == null || to == null
                        || !nodeIds.contains(from) || !nodeIds.contains(to)) {
                    throw new IllegalArgumentException("relation references undeclared node ids");
                }
                if (name == null || !allowed.contains(name)) {
                    throw new IllegalArgumentException("relation '" + name + "' is not allowed");
                }
            }

            Set<String> submitted = new LinkedHashSet<>();
            for (JsonNode rel : relations) {
                submitted.add(relationKey(rel));
            }

            JsonNodeFactory f = JsonNodeFactory.instance;
            ObjectNode out = f.objectNode();
            out.put("relationCount", relations.size());

            if (config.path("graded").asBoolean(false)) {
                return evaluateGraded(ctx, config, submitted, out);
            }
            return result(ActivityResult.COMPLETED, true, out,
                    feedbackFor(ctx.activity(), ActivityResult.COMPLETED));
        }

        private String relationKey(JsonNode rel) {
            return rel.path("from").asText("") + "|"
                    + rel.path("relation").asText("") + "|"
                    + rel.path("to").asText("");
        }

        /** Accepted answer sets: canonical expectedRelations plus any
         *  alternative acceptedRelationSets member (valid interpretations). */
        private List<Set<String>> acceptedSets(JsonNode config) {
            List<Set<String>> sets = new java.util.ArrayList<>();
            Set<String> canonical = relationSet(config.get("expectedRelations"));
            if (!canonical.isEmpty()) sets.add(canonical);
            JsonNode alts = config.get("acceptedRelationSets");
            if (alts != null && alts.isArray()) {
                for (JsonNode alt : alts) {
                    Set<String> s = relationSet(alt);
                    if (!s.isEmpty()) sets.add(s);
                }
            }
            return sets;
        }

        private Set<String> relationSet(JsonNode array) {
            Set<String> set = new LinkedHashSet<>();
            if (array != null && array.isArray()) {
                for (JsonNode rel : array) {
                    String from = rel.path("from").asText(null);
                    String to = rel.path("to").asText(null);
                    String name = rel.path("relation").asText(null);
                    if (from != null && to != null && name != null) {
                        set.add(from + "|" + name + "|" + to);
                    }
                }
            }
            return set;
        }

        /**
         * Opt-in graded mode (config.graded:true): the submitted relation set
         * must exactly equal one accepted set -> COMPLETED; otherwise PARTIAL
         * credit = |submitted n best accepted| / |best accepted|. Output only
         * reports counts/score — never the expected relations.
         */
        private ActivityResult evaluateGraded(AttemptContext ctx, JsonNode config,
                                              Set<String> submitted, ObjectNode out) {
            List<Set<String>> acceptedSets = acceptedSets(config);
            boolean right = acceptedSets.stream().anyMatch(submitted::equals);

            int bestMatch = 0;
            int bestSize = 0;
            for (Set<String> accepted : acceptedSets) {
                Set<String> hit = new LinkedHashSet<>(submitted);
                hit.retainAll(accepted);
                if (hit.size() > bestMatch) {
                    bestMatch = hit.size();
                    bestSize = accepted.size();
                } else if (hit.size() == bestMatch && accepted.size() > bestSize) {
                    bestSize = accepted.size();
                }
            }
            double score = bestSize == 0 ? 0.0 : (double) bestMatch / bestSize;

            int maxAttempts = config.path("maxAttempts").asInt(1);
            int attemptNo = priorAttempts(ctx) + 1;
            boolean exhausted = !right && attemptNo >= Math.max(maxAttempts, 1);
            boolean completed = right || exhausted;

            out.put("correct", right);
            out.put("score", score);
            out.put("matchedRelations", bestMatch);
            out.put("incorrectCount", submitted.size() - bestMatch);
            out.put("attemptCount", attemptNo);
            if (exhausted) out.put("exhausted", true);

            String outcome = right ? ActivityResult.COMPLETED
                    : bestMatch > 0 && !exhausted ? ActivityResult.PARTIAL
                    : ActivityResult.INCORRECT;
            return result(outcome, completed, out,
                    feedbackFor(ctx.activity(), exhausted ? "EXHAUSTED" : outcome));
        }
    }

    @Component
    public static class VerificationHandler extends AbstractActivityHandler {
        @Override public ActivityType supports() { return ActivityType.VERIFICATION; }

        @Override
        public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
            JsonNode config = config(ctx.activity());
            Set<String> required = config == null
                    ? Set.of()
                    : stringIds(config.get("requiredEvidenceIds"));
            String expected = config != null && config.hasNonNull("expectedHypothesis")
                    ? config.get("expectedHypothesis").asText() : null;

            // Locate the most recent HYPOTHESIS_CHOICE output in priorOutputs.
            JsonNode hypothesis = null;
            for (JsonNode out : ctx.priorOutputs().values()) {
                if (out != null && out.isObject() && out.hasNonNull("hypothesisId")) {
                    hypothesis = out;
                }
            }

            String outcome;
            if (hypothesis == null) {
                outcome = ActivityResult.CONTRADICTED;
            } else {
                String chosen = hypothesis.get("hypothesisId").asText();
                if (expected != null && !expected.equals(chosen)) {
                    outcome = ActivityResult.CONTRADICTED;
                } else {
                    Set<String> given = new LinkedHashSet<>();
                    JsonNode ev = hypothesis.get("evidenceIds");
                    if (ev != null && ev.isArray()) {
                        ev.forEach(n -> { if (n.isTextual()) given.add(n.asText()); });
                    }
                    outcome = given.containsAll(required)
                            ? ActivityResult.SUPPORTED : ActivityResult.PARTIAL;
                }
            }

            JsonNodeFactory f = JsonNodeFactory.instance;
            ObjectNode out = f.objectNode();
            out.put("verification", outcome);
            boolean completed = ActivityResult.SUPPORTED.equals(outcome);
            return result(outcome, completed, out,
                    feedbackFor(ctx.activity(), outcome));
        }
    }

    @Component
    public static class CerHandler extends AbstractActivityHandler {
        private static final int MIN_CHARS = 20;

        @Override public ActivityType supports() { return ActivityType.CER; }

        @Override
        public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
            String claim = requireText(sub.answer(), "claim");
            String reasoning = requireText(sub.answer(), "reasoning");
            if (claim.length() < MIN_CHARS || reasoning.length() < MIN_CHARS) {
                throw new IllegalArgumentException(
                        "claim and reasoning must each be at least " + MIN_CHARS + " chars");
            }
            List<String> evidenceIds = sub.answer() != null
                    && sub.answer().has("evidenceIds")
                    ? readIdList(sub.answer(), "evidenceIds")
                    : List.of();
            Set<String> snapshotEvidence = new LinkedHashSet<>();
            JsonNode ev = ctx.snapshot().get("evidence");
            if (ev != null && ev.isArray()) {
                ev.forEach(e -> {
                    JsonNode id = e.get("id");
                    if (id != null && id.isTextual()) snapshotEvidence.add(id.asText());
                });
            }
            JsonNodeFactory f = JsonNodeFactory.instance;
            ObjectNode out = f.objectNode();
            out.put("claim", claim);
            out.put("reasoning", reasoning);
            ArrayNode arr = out.putArray("evidenceIds");
            evidenceIds.stream().filter(snapshotEvidence::contains).forEach(arr::add);
            return result(ActivityResult.COMPLETED, true, out,
                    feedbackFor(ctx.activity(), ActivityResult.COMPLETED));
        }
    }
}
