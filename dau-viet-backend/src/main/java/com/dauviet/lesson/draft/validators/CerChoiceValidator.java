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
        if (config.has("evidenceOptions")) {
            JsonNode opts = config.get("evidenceOptions");
            if (opts.isArray()) {
                collectIds(opts, path + ".config.evidenceOptions", errors);
            } else {
                errors.add(new FieldError(path + ".config.evidenceOptions", "INVALID_CONFIG",
                        "evidenceOptions must be an array"));
            }
        }
        checkOptionalInt(config, "minCorrect", 1, 3, path, errors);
        checkOptionalInt(config, "maxAttempts", 1, 100, path, errors);
        JsonNode prior = config.get("priorEvidenceSource");
        if (prior != null && !prior.isNull()) {
            if (!prior.isTextual()
                    || !DraftSchema.ID_PATTERN.matcher(prior.asText()).matches()) {
                errors.add(new FieldError(path + ".config.priorEvidenceSource", "INVALID_ID",
                        "priorEvidenceSource must be a valid activity id"));
            }
        }

        if (!ctx.isPublish()) {
            return;
        }
        requireKeySubset(config, "acceptedClaims", claimIds, path, errors);
        requireKeySubset(config, "acceptedReasoningIds", reasoningIds, path, errors);
        requireNonEmptyArray(config, "acceptedEvidenceIds", path, 1, errors);
        checkEvidenceRefs(config, "acceptedEvidenceIds", path, ctx, errors);
        JsonNode feedback = activity.get("feedback");
        if (feedback == null || !feedback.isObject()
                || !feedback.hasNonNull("COMPLETED") || !feedback.hasNonNull("INCORRECT")) {
            errors.add(new FieldError(path + ".feedback", "MISSING_FIELD",
                    "feedback must define at least COMPLETED and INCORRECT"));
        }
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
