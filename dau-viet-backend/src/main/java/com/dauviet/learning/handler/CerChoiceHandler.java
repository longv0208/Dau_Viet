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
 * CER_CHOICE: structured Claim -> Evidence -> Reasoning conclusion graded
 * against admin-authored keys (acceptedClaims / acceptedEvidenceIds /
 * acceptedReasoningIds). Distinct from free-text CER: three picked parts,
 * per-part grading, minCorrect gate (default 3 = all parts).
 * Evidence ids are valid when declared in config.evidenceOptions OR present
 * in the pinned snapshot evidence[] (lets prior-source selections through).
 * Retry budget: config.maxAttempts (default 3); exhausted -> completed to
 * avoid soft-lock (same convention as MultipleChoiceHandler).
 */
@Component
public class CerChoiceHandler extends AbstractActivityHandler {

    private static final int DEFAULT_MAX_ATTEMPTS = 3;

    @Override
    public ActivityType supports() {
        return ActivityType.CER_CHOICE;
    }

    @Override
    public ActivityResult evaluate(AttemptContext ctx, ActivitySubmission sub) {
        JsonNode config = requireConfig(ctx.activity());

        String claimId = requireText(sub.answer(), "claimId");
        String reasoningId = requireText(sub.answer(), "reasoningId");
        List<String> evidenceIds = sub.answer() != null && sub.answer().has("evidenceIds")
                ? readIdList(sub.answer(), "evidenceIds")
                : List.of();

        Set<String> claimIds = objectIds(config, "claims");
        if (!claimIds.contains(claimId)) {
            throw new IllegalArgumentException("claimId is not a declared claim");
        }
        Set<String> reasoningIds = objectIds(config, "reasoningOptions");
        if (!reasoningIds.contains(reasoningId)) {
            throw new IllegalArgumentException("reasoningId is not a declared reasoning option");
        }
        Set<String> selectableEvidence = objectIds(config, "evidenceOptions");
        selectableEvidence.addAll(snapshotEvidenceIds(ctx));
        Set<String> selectedEvidence = new LinkedHashSet<>(evidenceIds);
        for (String id : selectedEvidence) {
            if (!selectableEvidence.contains(id)) {
                throw new IllegalArgumentException(
                        "evidence '" + id + "' is not selectable here");
            }
        }

        Set<String> acceptedClaims = stringIds(config.get("acceptedClaims"));
        Set<String> acceptedEvidence = stringIds(config.get("acceptedEvidenceIds"));
        Set<String> acceptedReasoning = stringIds(config.get("acceptedReasoningIds"));

        int partsCorrect = 0;
        if (acceptedClaims.contains(claimId)) partsCorrect++;
        if (!acceptedEvidence.isEmpty() && selectedEvidence.containsAll(acceptedEvidence)) partsCorrect++;
        if (acceptedReasoning.contains(reasoningId)) partsCorrect++;

        int minCorrect = config.path("minCorrect").asInt(3);
        boolean correct = partsCorrect >= Math.max(minCorrect, 1);

        int maxAttempts = config.path("maxAttempts").asInt(DEFAULT_MAX_ATTEMPTS);
        int attemptNo = priorAttempts(ctx) + 1;
        boolean exhausted = !correct && attemptNo >= Math.max(maxAttempts, 1);
        boolean completed = correct || exhausted;

        String outcome = correct ? ActivityResult.COMPLETED
                : partsCorrect > 0 && !exhausted ? ActivityResult.PARTIAL
                : ActivityResult.INCORRECT;

        JsonNodeFactory f = JsonNodeFactory.instance;
        ObjectNode out = f.objectNode();
        out.put("claimId", claimId);
        ArrayNode arr = out.putArray("evidenceIds");
        selectedEvidence.forEach(arr::add);
        out.put("reasoningId", reasoningId);
        out.put("partsCorrect", partsCorrect);
        out.put("correct", correct);
        out.put("attemptCount", attemptNo);
        if (exhausted) out.put("exhausted", true);

        return result(outcome, completed, out,
                feedbackFor(ctx.activity(), exhausted ? "EXHAUSTED" : outcome));
    }

    private Set<String> snapshotEvidenceIds(AttemptContext ctx) {
        Set<String> ids = new LinkedHashSet<>();
        JsonNode ev = ctx.snapshot() == null ? null : ctx.snapshot().get("evidence");
        if (ev != null && ev.isArray()) {
            ev.forEach(e -> {
                JsonNode id = e.get("id");
                if (id != null && id.isTextual()) ids.add(id.asText());
            });
        }
        return ids;
    }
}
