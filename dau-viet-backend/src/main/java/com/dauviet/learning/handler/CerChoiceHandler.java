package com.dauviet.learning.handler;

import java.util.ArrayList;
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
 * against admin-authored accepted combinations.
 *
 * Full correctness = the picked (claimId, evidenceIds-set, reasoningId) exactly
 * matches one authored combo. Combos come from:
 *  - config.acceptedCombos[] (canonical, Learning Flow 2.0): each element is
 *    {claimId, evidenceIds[], reasoningId}; supports multiple valid historical
 *    interpretations;
 *  - legacy shorthand (snapshots published before acceptedCombos): the
 *    cartesian product of acceptedClaims x acceptedEvidenceIds x
 *    acceptedReasoningIds. Per-part overlap alone can only ever earn PARTIAL
 *    credit — it never promotes a mismatched pick to correct, whatever
 *    minCorrect a legacy draft carries.
 *
 * Partial credit = best per-part overlap against the closest combo
 * (partsCorrect 0..3, score = partsCorrect/3) — wrong extra evidence keeps
 * that part at 0, so an answer marked incorrect can never read as fully
 * correct.
 *
 * Evidence ids are valid when declared in config.evidenceOptions, present in
 * the pinned snapshot evidence[], or collected by the upstream activity named
 * in config.priorEvidenceSource (priorOutputs).
 * Retry budget: config.maxAttempts (default 3); exhausted -> completed for
 * progress only (correct stays false) to avoid soft-lock.
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
        selectableEvidence.addAll(priorSourceEvidenceIds(ctx, config));
        Set<String> selectedEvidence = new LinkedHashSet<>(evidenceIds);
        for (String id : selectedEvidence) {
            if (!selectableEvidence.contains(id)) {
                throw new IllegalArgumentException(
                        "evidence '" + id + "' is not selectable here");
            }
        }

        List<Combo> combos = acceptedCombos(config);
        int partsCorrect = 0;
        boolean correct = false;
        for (Combo combo : combos) {
            int parts = 0;
            if (combo.claims().contains(claimId)) parts++;
            if (!combo.evidence().isEmpty() && selectedEvidence.equals(combo.evidence())) parts++;
            if (combo.reasoning().contains(reasoningId)) parts++;
            partsCorrect = Math.max(partsCorrect, parts);
            if (parts == 3) {
                correct = true;
                partsCorrect = 3;
                break;
            }
        }

        int maxAttempts = config.path("maxAttempts").asInt(DEFAULT_MAX_ATTEMPTS);
        int attemptNo = priorAttempts(ctx) + 1;
        boolean exhausted = !correct && attemptNo >= Math.max(maxAttempts, 1);
        // Exhausted completes the activity for PROGRESS only — correct stays
        // false so knowledge scoring never credits an unproven conclusion.
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
        out.put("score", partsCorrect / 3.0);
        out.put("correct", correct);
        out.put("attemptCount", attemptNo);
        if (exhausted) out.put("exhausted", true);

        return result(outcome, completed, out,
                feedbackFor(ctx.activity(), exhausted ? "EXHAUSTED" : outcome));
    }

    /**
     * One accepted interpretation: the full (claim, evidence set, reasoning)
     * combination that counts as a correct conclusion. Each field is a SET of
     * ids (combo expansion means each combo usually holds singletons).
     */
    private record Combo(Set<String> claims, Set<String> evidence, Set<String> reasoning) {
    }

    /**
     * Canonical combos from config.acceptedCombos[]; when absent (snapshots
     * published by earlier drafts) expand the legacy three flat arrays into
     * their cartesian product so old CER_CHOICE versions keep working.
     */
    private List<Combo> acceptedCombos(JsonNode config) {
        List<Combo> combos = new ArrayList<>();
        JsonNode authored = config.get("acceptedCombos");
        if (authored != null && authored.isArray()) {
            for (JsonNode c : authored) {
                if (!c.isObject()) continue;
                Set<String> claims = new LinkedHashSet<>();
                JsonNode claimId = c.get("claimId");
                if (claimId != null && claimId.isTextual()) claims.add(claimId.asText());
                Set<String> ev = stringIds(c.get("evidenceIds"));
                Set<String> re = new LinkedHashSet<>();
                JsonNode reasoningId = c.get("reasoningId");
                if (reasoningId != null && reasoningId.isTextual()) re.add(reasoningId.asText());
                if (!claims.isEmpty() && !re.isEmpty()) {
                    combos.add(new Combo(claims, ev, re));
                }
            }
            if (!combos.isEmpty()) return combos;
        }
        Set<String> claims = stringIds(config.get("acceptedClaims"));
        Set<String> evidence = stringIds(config.get("acceptedEvidenceIds"));
        Set<String> reasoning = stringIds(config.get("acceptedReasoningIds"));
        for (String c : claims) {
            for (String r : reasoning) {
                combos.add(new Combo(Set.of(c), new LinkedHashSet<>(evidence), Set.of(r)));
            }
        }
        return combos;
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

    /**
     * Evidence ids the upstream activity named by config.priorEvidenceSource
     * actually selected — the proven pool the learner may reuse. Missing or
     * malformed source output contributes nothing (never trust the client).
     */
    private Set<String> priorSourceEvidenceIds(AttemptContext ctx, JsonNode config) {
        String source = config.hasNonNull("priorEvidenceSource")
                ? config.get("priorEvidenceSource").asText() : null;
        if (source == null) return Set.of();
        JsonNode out = ctx.priorOutputs().get(source);
        JsonNode ids = out == null ? null : out.get("selectedEvidenceIds");
        if (ids == null || !ids.isArray()) return Set.of();
        Set<String> given = new LinkedHashSet<>();
        ids.forEach(n -> { if (n.isTextual()) given.add(n.asText()); });
        return given;
    }
}
