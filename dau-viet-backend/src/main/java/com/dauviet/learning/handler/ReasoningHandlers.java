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
         * must exactly equal one accepted set -> COMPLETED. Partial credit is
         * the MAXIMUM F1 computed independently against every accepted set —
         * F1 = 2·hits/(|submitted|+|accepted|) — so alternative answer sets
         * of different sizes each get their own score and the best wins
         * (previously the set was chosen by max hit COUNT, which could pick
         * a larger, worse-F1 interpretation). Extra incorrect relations
         * always lower the score below 1.0; an exact match on ANY accepted
         * set scores 1.0. Output only reports counts/score — never the
         * expected relations.
         */
        private ActivityResult evaluateGraded(AttemptContext ctx, JsonNode config,
                                              Set<String> submitted, ObjectNode out) {
            List<Set<String>> acceptedSets = acceptedSets(config);
            boolean right = acceptedSets.stream().anyMatch(submitted::equals);

            double score = 0.0;
            int bestMatch = 0;
            for (Set<String> accepted : acceptedSets) {
                Set<String> hit = new LinkedHashSet<>(submitted);
                hit.retainAll(accepted);
                double f1 = accepted.isEmpty() ? 0.0
                        : 2.0 * hit.size() / (submitted.size() + accepted.size());
                if (f1 > score) {
                    score = f1;
                    bestMatch = hit.size();
                }
            }

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

        /**
         * config.maxAttempts (TASK-0020 round-3 FIX 1): bounds how many times
         * a learner may re-attempt verification. When the budget is spent on a
         * non-SUPPORTED outcome the activity completes-for-progress anyway —
         * the recorded verdict stays PARTIAL/CONTRADICTED (never promoted to
         * SUPPORTED), the review hop fires on the way there, and the lesson
         * can reach a deliberate terminal state instead of looping forever
         * between Verification and an upstream activity that can no longer
         * change its output. Default 0 keeps legacy snapshots unbounded.
         */
        @Override
        public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
            JsonNode config = config(ctx.activity());
            Set<String> required = config == null
                    ? Set.of()
                    : stringIds(config.get("requiredEvidenceIds"));
            String expected = config != null && config.hasNonNull("expectedHypothesis")
                    ? config.get("expectedHypothesis").asText() : null;
            String source = config != null && config.hasNonNull("evidenceSource")
                    ? config.get("evidenceSource").asText() : null;

            // Locate the most recent HYPOTHESIS_CHOICE output in priorOutputs
            // (or explicit config.hypothesisSource if authored).
            JsonNode hypothesis = null;
            if (config != null && config.hasNonNull("hypothesisSource")) {
                JsonNode explicitHyp = ctx.priorOutputs()
                        .get(config.get("hypothesisSource").asText());
                if (explicitHyp != null && explicitHyp.isObject()
                        && explicitHyp.hasNonNull("hypothesisId")) {
                    hypothesis = explicitHyp;
                }
            }
            if (hypothesis == null) {
                for (JsonNode out : ctx.priorOutputs().values()) {
                    if (out != null && out.isObject() && out.hasNonNull("hypothesisId")) {
                        hypothesis = out;
                    }
                }
            }

            // Interactive Step 3 Verification: when no upstream evidenceSource
            // is forced and the learner submits selectedEvidenceIds directly,
            // validate the submitted evidence against snapshot/visibleSourceIds.
            boolean isFourStep = ctx.snapshot() != null
                    && "FOUR_STEP".equals(
                            ctx.snapshot().path("flowModel").asText(null));
            boolean interactiveSelection = (source == null || source.isBlank())
                    && sub.answer() != null
                    && sub.answer().isObject()
                    && sub.answer().has("selectedEvidenceIds")
                    && sub.answer().get("selectedEvidenceIds").isArray();

            // FOUR_STEP snapshot: interactive verification is REQUIRED —
            // reject legacy evidenceSource fallback. Legacy snapshots keep
            // the old evidenceSource / priorOutputs path.
            if (isFourStep && !interactiveSelection) {
                throw new IllegalArgumentException(
                        "FOUR_STEP VERIFICATION requires answer.selectedEvidenceIds array");
            }
            if (isFourStep && source != null && !source.isBlank()) {
                throw new IllegalArgumentException(
                        "FOUR_STEP VERIFICATION does not support evidenceSource — "
                        + "use interactive selectedEvidenceIds");
            }

            Set<String> interactiveSelected = Set.of();
            if (interactiveSelection) {
                List<String> rawIds = readIdList(sub.answer(), "selectedEvidenceIds");
                interactiveSelected = new LinkedHashSet<>(rawIds);
                validateInteractiveEvidence(ctx, config, interactiveSelected);
            }

            String outcome;
            String subOutcome = null;
            int matchedCount = 0;
            int falseCount = 0;
            if (hypothesis == null) {
                outcome = ActivityResult.CONTRADICTED;
                subOutcome = "MISSING_HYPOTHESIS";
            } else {
                String chosen = hypothesis.get("hypothesisId").asText();
                if (expected != null && !expected.equals(chosen)) {
                    outcome = ActivityResult.CONTRADICTED;
                    subOutcome = "HYPOTHESIS_CONTRADICTED";
                } else if (interactiveSelection) {
                    if (required.isEmpty()) {
                        // Publish-level validation requires requiredEvidenceIds.
                        // Reaching here means a draft bypassed publish validation —
                        // do NOT silently SUPPORTED any selection.
                        throw new IllegalArgumentException(
                                "interactive VERIFICATION requires config.requiredEvidenceIds");
                    } else {
                        Set<String> hits = new LinkedHashSet<>(interactiveSelected);
                        hits.retainAll(required);
                        matchedCount = hits.size();
                        falseCount = interactiveSelected.size() - hits.size();
                        if (interactiveSelected.equals(required)) {
                            outcome = ActivityResult.SUPPORTED;
                            subOutcome = "SUPPORTED";
                        } else if (hits.isEmpty() && !interactiveSelected.isEmpty()) {
                            outcome = ActivityResult.CONTRADICTED;
                            subOutcome = "EVIDENCE_CONTRADICTED";
                        } else if (hits.size() < required.size() && falseCount == 0) {
                            outcome = ActivityResult.PARTIAL;
                            subOutcome = "INSUFFICIENT_EVIDENCE";
                        } else {
                            outcome = ActivityResult.PARTIAL;
                            subOutcome = "PARTIAL_SUPPORT";
                        }
                    }
                } else {
                    Set<String> given = evidenceGiven(ctx, config, hypothesis);
                    outcome = given.containsAll(required)
                            ? ActivityResult.SUPPORTED : ActivityResult.PARTIAL;
                    subOutcome = outcome;
                }
            }

            JsonNodeFactory f = JsonNodeFactory.instance;
            ObjectNode out = f.objectNode();
            out.put("verification", outcome);
            if (subOutcome != null) {
                out.put("subOutcome", subOutcome);
            }
            if (hypothesis != null && hypothesis.hasNonNull("hypothesisId")) {
                out.put("hypothesisId", hypothesis.get("hypothesisId").asText());
            }
            if (interactiveSelection) {
                ArrayNode selArr = out.putArray("selectedEvidenceIds");
                interactiveSelected.forEach(selArr::add);
                out.put("selectedCount", interactiveSelected.size());
                out.put("matchedCount", matchedCount);
                out.put("falseCount", falseCount);
                out.put("requiredCount", required.size());
            }
            int attemptNo = priorAttempts(ctx) + 1;
            out.put("attemptCount", attemptNo);
            int maxAttempts = config == null ? 0
                    : config.path("maxAttempts").asInt(0);
            if (!ActivityResult.SUPPORTED.equals(outcome) && maxAttempts <= 0) {
                String reviseField = ActivityResult.PARTIAL.equals(outcome)
                        ? "onPartial" : "onContradicted";
                String reviseTarget = ctx.activity() == null ? null
                        : ctx.activity().path(reviseField).asText(null);
                if (reviseTarget == null || reviseTarget.isBlank()) {
                    maxAttempts = 2;
                }
            }
            boolean completed = ActivityResult.SUPPORTED.equals(outcome)
                    || (maxAttempts > 0 && attemptNo >= maxAttempts);
            if (completed && !ActivityResult.SUPPORTED.equals(outcome)) {
                out.put("exhausted", true);
            }
            return result(outcome, completed, out,
                    feedbackFor(ctx.activity(), outcome));
        }

        private void validateInteractiveEvidence(AttemptContext ctx, JsonNode config,
                                                 Set<String> selected) {
            Set<String> snapshotEvidence = new LinkedHashSet<>();
            JsonNode ev = ctx.snapshot().get("evidence");
            if (ev != null && ev.isArray()) {
                ev.forEach(e -> {
                    JsonNode id = e.get("id");
                    if (id != null && id.isTextual()) snapshotEvidence.add(id.asText());
                });
            }
            Set<String> visible = new LinkedHashSet<>();
            if (config != null) {
                visible.addAll(stringIds(config.get("visibleSourceIds")));
                visible.addAll(stringIds(config.get("visibleEvidenceIds")));
            }
            for (String id : selected) {
                if (!snapshotEvidence.isEmpty() && !snapshotEvidence.contains(id)) {
                    throw new IllegalArgumentException(
                            "evidence '" + id + "' not in published snapshot");
                }
                if (!visible.isEmpty() && !visible.contains(id)) {
                    throw new IllegalArgumentException(
                            "evidence '" + id + "' is not selectable here");
                }
            }
        }

        /**
         * Evidence set the verdict is checked against (Learning Flow 2.0 §P0):
         * - `config.evidenceSource` names an upstream EVIDENCE_SELECT activity —
         *   the persisted output's `selectedEvidenceIds` is the authoritative
         *   evidence set (learners never re-pick the same evidence, and any
         *   client-submitted ids are ignored entirely).
         * - Without it (legacy snapshots): fall back to the evidenceIds the
         *   HYPOTHESIS_CHOICE output itself recorded — old versions unchanged.
         * When the source was authored but its output is missing or malformed,
         * the result is an empty set -> PARTIAL (never trust the client).
         */
        private Set<String> evidenceGiven(AttemptContext ctx, JsonNode config,
                                          JsonNode hypothesis) {
            String source = config != null && config.hasNonNull("evidenceSource")
                    ? config.get("evidenceSource").asText() : null;
            JsonNode carrier;
            String field;
            if (source != null) {
                carrier = ctx.priorOutputs().get(source);
                field = "selectedEvidenceIds";
            } else {
                carrier = hypothesis;
                field = "evidenceIds";
            }
            Set<String> given = new LinkedHashSet<>();
            JsonNode ids = carrier == null ? null : carrier.get(field);
            if (ids != null && ids.isArray()) {
                ids.forEach(n -> { if (n.isTextual()) given.add(n.asText()); });
            }
            if (given.isEmpty()) {
                for (JsonNode out : ctx.priorOutputs().values()) {
                    if (out != null && out.isObject()) {
                        JsonNode selected = out.get("selectedEvidenceIds");
                        if (selected != null && selected.isArray() && !selected.isEmpty()) {
                            selected.forEach(n -> { if (n.isTextual()) given.add(n.asText()); });
                        }
                    }
                }
            }
            return given;
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
