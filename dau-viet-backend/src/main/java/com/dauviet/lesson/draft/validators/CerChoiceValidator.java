package com.dauviet.lesson.draft.validators;

import java.util.List;
import java.util.Set;

import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.JsonNode;

import com.dauviet.lesson.draft.ActivityType;
import com.dauviet.lesson.draft.DraftSchema;
import com.dauviet.lesson.draft.FieldError;
import com.dauviet.lesson.draft.ValidationContext;

/**
 * CER_CHOICE: structured claim+evidence+reasoning pick with server-side keys.
 * SAVE level checks shape only (option lists, id uniqueness, optional ints).
 * PUBLISH level additionally requires the three answer-key arrays, each a
 * subset of its declared option ids; acceptedEvidenceIds must be usable
 * evidence for the event.
 */
@Component
public class CerChoiceValidator extends AbstractActivityValidator {

    @Override
    public ActivityType supports() {
        return ActivityType.CER_CHOICE;
    }

    @Override
    public void validate(JsonNode activity, String path, ValidationContext ctx,
                         List<FieldError> errors) {
        JsonNode config = config(activity);
        if (config == null) {
            errors.add(new FieldError(path + ".config", "MISSING_FIELD", "config is required"));
            return;
        }
        requireNonEmptyArray(config, "claims", path, 2, errors);
        requireNonEmptyArray(config, "reasoningOptions", path, 2, errors);
        Set<String> claimIds = config.has("claims")
                ? collectIds(config.get("claims"), path + ".config.claims", errors)
                : Set.of();
        Set<String> reasoningIds = config.has("reasoningOptions")
                ? collectIds(config.get("reasoningOptions"), path + ".config.reasoningOptions", errors)
                : Set.of();
        Set<String> optionIds = Set.of();
        if (config.has("evidenceOptions")) {
            JsonNode opts = config.get("evidenceOptions");
            if (opts.isArray()) {
                optionIds = collectIds(opts, path + ".config.evidenceOptions", errors);
            } else {
                errors.add(new FieldError(path + ".config.evidenceOptions", "INVALID_CONFIG",
                        "evidenceOptions must be an array"));
            }
        }
        // TASK-0020 §P4: minCorrect is retired — partial credit is already
        // bounded by partsCorrect/3 in the handler; a legacy minCorrect that
        // promoted partial picks to full correctness is exactly the bug the
        // coherent-combo rule removes. Reject it at publish so new drafts
        // cannot re-introduce the promotion path.
        if (ctx.isPublish() && config.hasNonNull("minCorrect")) {
            errors.add(new FieldError(path + ".config.minCorrect", "INVALID_CONFIG",
                    "minCorrect is retired: correctness requires a full accepted "
                            + "combination (acceptedCombos)"));
        } else {
            checkOptionalInt(config, "minCorrect", 1, 3, path, errors);
        }
        checkOptionalInt(config, "maxAttempts", 1, 100, path, errors);
        JsonNode prior = config.get("priorEvidenceSource");
        if (prior != null && !prior.isNull()) {
            if (!prior.isTextual()
                    || !DraftSchema.ID_PATTERN.matcher(prior.asText()).matches()) {
                errors.add(new FieldError(path + ".config.priorEvidenceSource", "INVALID_ID",
                        "priorEvidenceSource must be a valid activity id"));
            }
        }

        // TASK-0020 §P4: acceptedCombos[] — authored coherent combinations.
        // Each element {claimId, evidenceIds[], reasoningId}; when present it
        // is the canonical key and the legacy flat arrays are ignored.
        boolean hasCombos = validateCombos(config, claimIds, reasoningIds,
                optionIds, path, ctx, errors);

        if (!ctx.isPublish()) {
            return;
        }
        if (!hasCombos) {
            // Legacy shape only: the three flat key arrays are required and
            // acceptedEvidenceIds must be pickable — i.e. inside the declared
            // evidenceOptions pool (the upstream priorEvidenceSource pool is
            // runtime data a draft cannot enumerate; authored keys must be
            // declared ids, TASK-0020 §P5).
            requireKeySubset(config, "acceptedClaims", claimIds, path, errors);
            requireKeySubset(config, "acceptedReasoningIds", reasoningIds, path, errors);
            requireNonEmptyArray(config, "acceptedEvidenceIds", path, 1, errors);
            requireSubset(collectStringIds(config.get("acceptedEvidenceIds")),
                    optionIds, path + ".config.acceptedEvidenceIds",
                    "INVALID_CONFIG", errors);
            checkEvidenceRefs(config, "acceptedEvidenceIds", path, ctx, errors);
        }
        JsonNode feedback = activity.get("feedback");
        if (feedback == null || !feedback.isObject()
                || !feedback.hasNonNull("COMPLETED") || !feedback.hasNonNull("INCORRECT")) {
            errors.add(new FieldError(path + ".feedback", "MISSING_FIELD",
                    "feedback must define at least COMPLETED and INCORRECT"));
        }
    }

    /**
     * Validate config.acceptedCombos[] structure and references. Returns true
     * when at least one well-formed combo exists (canonical key present).
     * Malformed elements are reported but do not satisfy the publish key
     * requirement — a combo the learner can never match is a dead answer.
     */
    private boolean validateCombos(JsonNode config, Set<String> claimIds,
                                   Set<String> reasoningIds, Set<String> optionIds,
                                   String path, ValidationContext ctx,
                                   List<FieldError> errors) {
        JsonNode combos = config.get("acceptedCombos");
        if (combos == null || combos.isNull()) return false;
        String base = path + ".config.acceptedCombos";
        if (!combos.isArray() || combos.isEmpty()) {
            errors.add(new FieldError(base, "INVALID_CONFIG",
                    "acceptedCombos must be a non-empty array"));
            return false;
        }
        // Selectable pool: declared evidenceOptions ∪ snapshot evidence.
        // The upstream priorEvidenceSource pool can only add ids the source
        // may select — unknown at draft level — so authored ids outside
        // evidenceOptions are flagged at publish (selectable ids must be
        // declared; TASK-0020 §P5).
        int valid = 0;
        for (int i = 0; i < combos.size(); i++) {
            JsonNode c = combos.get(i);
            String cp = base + "[" + i + "]";
            if (!c.isObject()) {
                errors.add(new FieldError(cp, "INVALID_TYPE", "combo must be an object"));
                continue;
            }
            boolean ok = true;
            JsonNode claimId = c.get("claimId");
            if (claimId == null || !claimId.isTextual()) {
                errors.add(new FieldError(cp + ".claimId", "MISSING_FIELD",
                        "combo.claimId is required"));
                ok = false;
            } else if (ctx.isPublish() && !claimIds.contains(claimId.asText())) {
                errors.add(new FieldError(cp + ".claimId", "INVALID_CONFIG",
                        "combo.claimId '" + claimId.asText() + "' is not a declared claim"));
                ok = false;
            }
            JsonNode reasoningId = c.get("reasoningId");
            if (reasoningId == null || !reasoningId.isTextual()) {
                errors.add(new FieldError(cp + ".reasoningId", "MISSING_FIELD",
                        "combo.reasoningId is required"));
                ok = false;
            } else if (ctx.isPublish() && !reasoningIds.contains(reasoningId.asText())) {
                errors.add(new FieldError(cp + ".reasoningId", "INVALID_CONFIG",
                        "combo.reasoningId '" + reasoningId.asText()
                                + "' is not a declared reasoning option"));
                ok = false;
            }
            JsonNode evIds = c.get("evidenceIds");
            if (evIds == null || !evIds.isArray() || evIds.isEmpty()) {
                errors.add(new FieldError(cp + ".evidenceIds", "MISSING_FIELD",
                        "combo.evidenceIds must be a non-empty array"));
                ok = false;
            } else {
                Set<String> ids = collectStringIds(evIds);
                if (ctx.isPublish()) {
                    requireSubset(ids, optionIds, cp + ".evidenceIds",
                            "INVALID_CONFIG", errors);
                    for (int k = 0; k < evIds.size(); k++) {
                        String evId = evIds.get(k).asText();
                        if (!ctx.evidenceUsable(evId)) {
                            errors.add(new FieldError(cp + ".evidenceIds[" + k + "]",
                                    "EVIDENCE_NOT_FOUND",
                                    "evidence '" + evId + "' not usable for this event"));
                            ok = false;
                        }
                    }
                }
            }
            if (ok) valid++;
        }
        if (ctx.isPublish() && valid == 0) {
            errors.add(new FieldError(base, "INVALID_CONFIG",
                    "acceptedCombos must contain at least one complete combination"));
        }
        return valid > 0;
    }

    private void requireKeySubset(JsonNode config, String field, Set<String> universe,
                                  String path, List<FieldError> errors) {
        JsonNode arr = config.get(field);
        if (arr == null || !arr.isArray() || arr.isEmpty()) {
            errors.add(new FieldError(path + ".config." + field, "MISSING_FIELD",
                    field + " is required for publish"));
            return;
        }
        requireSubset(collectStringIds(arr), universe, path + ".config." + field,
                "INVALID_CONFIG", errors);
    }

    private void checkOptionalInt(JsonNode config, String field, int min, int max,
                                  String path, List<FieldError> errors) {
        JsonNode v = config.get(field);
        if (v == null || v.isNull()) return;
        if (!v.isInt() || v.asInt() < min || v.asInt() > max) {
            errors.add(new FieldError(path + ".config." + field, "INVALID_VALUE",
                    field + " must be an integer in [" + min + ".." + max + "]"));
        }
    }
}
