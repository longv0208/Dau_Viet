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
 * Selection activities. EVIDENCE_SELECT: ids must be visible + inside the
 * snapshot evidence[] and meet config.minRequired (default 1); the hidden
 * requiredEvidenceIds answer key is NOT consulted (VERIFICATION grades that).
 * Duplicate submitted ids dedupe to a LinkedHashSet before minRequired so
 * [A,A] can't satisfy minRequired=2 and output/collection stay consistent.
 * HYPOTHESIS_CHOICE: records the chosen hypothesis + supporting evidence for
 * downstream VERIFICATION — no correctness per BA.
 */
public final class SelectionHandlers {

    private SelectionHandlers() {
    }

    @Component
    public static class EvidenceSelectHandler extends AbstractActivityHandler {
        @Override public ActivityType supports() { return ActivityType.EVIDENCE_SELECT; }

        @Override
        public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
            JsonNode config = requireConfig(ctx.activity());
            List<String> selected = readIdList(sub.answer(), "selectedEvidenceIds");
            Set<String> snapshotEvidence = snapshotEvidenceIds(ctx);
            Set<String> visible = stringIds(config.get("visibleEvidenceIds"));
            // Dedup giữ thứ tự submit — [A,B,A] tính 2 mục, không 3.
            Set<String> distinct = new LinkedHashSet<>(selected);
            for (String id : distinct) {
                if (!snapshotEvidence.contains(id)) {
                    throw new IllegalArgumentException(
                            "evidence '" + id + "' not in published snapshot");
                }
                if (!visible.isEmpty() && !visible.contains(id)) {
                    throw new IllegalArgumentException(
                            "evidence '" + id + "' is not selectable here");
                }
            }
            JsonNodeFactory f = JsonNodeFactory.instance;
            ObjectNode out = f.objectNode();
            ArrayNode arr = out.putArray("selectedEvidenceIds");
            distinct.forEach(arr::add);
            out.put("selectedCount", distinct.size());

            Set<String> accepted = stringIds(config.get("acceptedEvidenceIds"));
            boolean graded = config.path("graded").asBoolean(false) && !accepted.isEmpty();
            if (graded) {
                return evaluateGraded(ctx, config, distinct, accepted, out);
            }

            int minRequired = config.path("minRequired").asInt(1);
            boolean done = distinct.size() >= Math.max(minRequired, 1);
            return result(done ? ActivityResult.COMPLETED : ActivityResult.IN_PROGRESS,
                    done, out, feedbackFor(ctx.activity(),
                            done ? ActivityResult.COMPLETED : ActivityResult.IN_PROGRESS));
        }

        /**
         * Opt-in graded mode (config.graded:true + acceptedEvidenceIds key):
         * exact set match -> COMPLETED. Partial credit = F1 of the selected
         * set against the accepted set — 2·hits/(|selected|+|accepted|) — so
         * wrong extra picks always pull the score below 1.0 and select-all
         * can never farm full credit.
         *
         * Retry budget: config.maxAttempts scored attempts (default 1);
         * exhaustion still completes for progress (never a soft-lock by
         * itself). config.remedialAttempts adds a SMALL remediation budget
         * that only unlocks once the learner has exhausted the scored budget
         * AND was routed back here by a downstream REVISE hop (cursor-based,
         * not a standing free retry) — an exhausted activity re-submitted
         * from a later stage stays exhausted instead of looping forever on a
         * Verification PARTIAL it can never satisfy. Correctness is still
         * exact-match only: a remedial submission that misses keeps
         * correct:false and its real F1 score — no credit inflation, no
         * reward exploit (remedial attempts are capped like scored ones).
         */
        private ActivityResult evaluateGraded(AttemptContext ctx, JsonNode config,
                                              Set<String> selected, Set<String> accepted,
                                              ObjectNode out) {
            Set<String> correctHits = new LinkedHashSet<>(selected);
            correctHits.retainAll(accepted);
            int falseCount = selected.size() - correctHits.size();
            double score = accepted.isEmpty() || selected.isEmpty() ? 0.0
                    : 2.0 * correctHits.size() / (selected.size() + accepted.size());
            boolean right = selected.equals(accepted);

            int maxAttempts = Math.max(config.path("maxAttempts").asInt(1), 1);
            int remedialAttempts = Math.max(
                    config.path("remedialAttempts").asInt(0), 0);
            int attemptNo = priorAttempts(ctx) + 1;
            boolean exhausted = !right && attemptNo >= maxAttempts;

            // Policy B (TASK-0020 final): the scored+remedial budget is a hard
            // cap on CORRECTNESS. Once spent, any further submission keeps the
            // activity completed-for-progress and the stored verdict/score —
            // the learner may still submit (the cursor never 409-soft-locks),
            // but correctness cannot be upgraded by exceeding the budget.
            JsonNode prior = ctx.priorOutputs().get(ctx.activityId());
            boolean overBudget = attemptNo > maxAttempts + remedialAttempts;
            boolean lockedCorrect = prior != null
                    && prior.path("correct").asBoolean(false);
            double lockedScore = prior != null && prior.hasNonNull("score")
                    ? prior.get("score").asDouble() : score;
            if (overBudget) {
                // Keep the LAST accepted selection too — overwriting
                // selectedEvidenceIds with a now-correct list would let
                // downstream consumers (Verification evidenceSource) see a
                // "right" evidence set the locked verdict never earned.
                if (prior != null && prior.hasNonNull("selectedEvidenceIds")) {
                    out.set("selectedEvidenceIds",
                            prior.get("selectedEvidenceIds").deepCopy());
                    out.put("selectedCount",
                            prior.path("selectedCount").asInt(
                                    prior.get("selectedEvidenceIds").size()));
                }
                if (prior != null && prior.hasNonNull("selectedVerdicts")) {
                    out.set("selectedVerdicts",
                            prior.get("selectedVerdicts").deepCopy());
                }
                out.put("correct", lockedCorrect);
                out.put("score", lockedScore);
                out.put("budgetExhausted", true);
                out.put("exhausted", true);
                out.put("attemptCount", attemptNo);
                out.put("correctCount", correctHits.size());
                out.put("falseCount", falseCount);
                out.put("totalItems", accepted.size());
                return result(ActivityResult.INCORRECT, true, out,
                        feedbackFor(ctx.activity(), "EXHAUSTED"));
            }

            // Remedial retry only counts when the scored budget is already
            // spent AND the persisted cursor sits on this activity (the
            // resolver holds it there while remedialAttempts remain). A
            // correct answer on the remedial try is still the normal
            // COMPLETED path — the marker is output metadata for audit, not
            // a different grading rule. On the forward path a wrong
            // submission is a normal scored attempt — never remedial — so
            // the budget can't be farmed for free credit early in the flow.
            boolean wasCompletedByExhaustion = prior != null
                    && prior.path("exhausted").asBoolean(false);
            boolean routedBack = ctx.activityId().equals(ctx.currentActivityId());
            // In the remedial window once the scored budget is spent and the
            // learner was routed back (cursor on this activity again after
            // completing-for-progress). `remedial` marks the attempt for
            // audit; `stillRetryable` keeps completed=false ONLY while a
            // further remedial try remains — the final remedial attempt
            // completes-for-progress regardless, so the flow terminates.
            boolean inRemedialWindow = wasCompletedByExhaustion && routedBack;
            boolean remedial = inRemedialWindow
                    && attemptNo <= maxAttempts + remedialAttempts;
            boolean stillRetryable = remedial
                    && attemptNo < maxAttempts + remedialAttempts;
            if (remedial) out.put("remedial", true);
            boolean completed = right || (exhausted && !stillRetryable);

            out.put("correct", right);
            out.put("score", score);
            out.put("correctCount", correctHits.size());
            out.put("falseCount", falseCount);
            out.put("totalItems", accepted.size());
            out.put("attemptCount", attemptNo);
            if (exhausted) out.put("exhausted", true);
            if (!selected.isEmpty()) {
                ObjectNode verdicts = out.putObject("selectedVerdicts");
                for (String id : selected) {
                    verdicts.put(id, correctHits.contains(id) ? "correct" : "incorrect");
                }
            }

            String outcome = right ? ActivityResult.COMPLETED
                    : !correctHits.isEmpty() && !exhausted ? ActivityResult.PARTIAL
                    : ActivityResult.INCORRECT;
            return result(outcome, completed, out,
                    feedbackFor(ctx.activity(), exhausted ? "EXHAUSTED" : outcome));
        }

        private Set<String> snapshotEvidenceIds(AttemptContext ctx) {
            Set<String> ids = new LinkedHashSet<>();
            JsonNode ev = ctx.snapshot().get("evidence");
            if (ev != null && ev.isArray()) {
                ev.forEach(e -> {
                    JsonNode id = e.get("id");
                    if (id != null && id.isTextual()) ids.add(id.asText());
                });
            }
            return ids;
        }
    }

    @Component
    public static class HypothesisChoiceHandler extends AbstractActivityHandler {
        @Override public ActivityType supports() { return ActivityType.HYPOTHESIS_CHOICE; }

        @Override
        public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
            JsonNode config = requireConfig(ctx.activity());
            String hypothesisId = requireText(sub.answer(), "hypothesisId");
            Set<String> valid = objectIds(config, "hypotheses");
            if (!valid.contains(hypothesisId)) {
                throw new IllegalArgumentException("hypothesisId is not a declared hypothesis");
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
            for (String id : evidenceIds) {
                if (!snapshotEvidence.contains(id)) {
                    throw new IllegalArgumentException(
                            "evidence '" + id + "' not in published snapshot");
                }
            }
            JsonNodeFactory f = JsonNodeFactory.instance;
            ObjectNode out = f.objectNode();
            out.put("hypothesisId", hypothesisId);
            ArrayNode arr = out.putArray("evidenceIds");
            evidenceIds.forEach(arr::add);
            return result(ActivityResult.COMPLETED, true, out,
                    feedbackFor(ctx.activity(), ActivityResult.COMPLETED));
        }
    }
}
