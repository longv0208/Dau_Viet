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
            int minRequired = config.path("minRequired").asInt(1);
            JsonNodeFactory f = JsonNodeFactory.instance;
            ObjectNode out = f.objectNode();
            ArrayNode arr = out.putArray("selectedEvidenceIds");
            distinct.forEach(arr::add);
            out.put("selectedCount", distinct.size());
            boolean done = distinct.size() >= Math.max(minRequired, 1);
            return result(done ? ActivityResult.COMPLETED : ActivityResult.IN_PROGRESS,
                    done, out, feedbackFor(ctx.activity(),
                            done ? ActivityResult.COMPLETED : ActivityResult.IN_PROGRESS));
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
