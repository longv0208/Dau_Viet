package com.dauviet.lesson.draft.validators;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.fasterxml.jackson.databind.JsonNode;

import com.dauviet.lesson.draft.ActivityConfigValidator;
import com.dauviet.lesson.draft.FieldError;
import com.dauviet.lesson.draft.ValidationContext;

/**
 * Shared helpers for per-type validators: config extraction and
 * small assertions that append FieldError instead of throwing.
 */
abstract class AbstractActivityValidator implements ActivityConfigValidator {

    protected JsonNode config(JsonNode activity) {
        JsonNode c = activity.get("config");
        return (c != null && c.isObject()) ? c : null;
    }

    protected void requireField(JsonNode config, String field, String path,
                                List<FieldError> errors) {
        if (config == null || config.get(field) == null || config.get(field).isNull()) {
            errors.add(new FieldError(path + ".config." + field, "MISSING_FIELD",
                    field + " is required"));
        }
    }

    protected void requireNonEmptyArray(JsonNode config, String field, String path,
                                        int min, List<FieldError> errors) {
        JsonNode arr = config == null ? null : config.get(field);
        if (arr == null || !arr.isArray() || arr.size() < min) {
            errors.add(new FieldError(path + ".config." + field, "INVALID_CONFIG",
                    field + " must be an array of at least " + min + " item(s)"));
        }
    }

    /** Collect element ids from an array field; flags duplicates and non-string ids. */
    protected Set<String> collectIds(JsonNode arr, String path, List<FieldError> errors) {
        Set<String> ids = new HashSet<>();
        if (arr == null || !arr.isArray()) return ids;
        for (int i = 0; i < arr.size(); i++) {
            JsonNode el = arr.get(i);
            JsonNode idNode = el.isObject() ? el.get("id") : el;
            if (idNode == null || !idNode.isTextual()) {
                errors.add(new FieldError(path + "[" + i + "].id", "MISSING_FIELD",
                        "item id is required"));
                continue;
            }
            String id = idNode.asText();
            if (!ids.add(id)) {
                errors.add(new FieldError(path + "[" + i + "].id", "DUPLICATE_ID",
                        "duplicate id '" + id + "'"));
            }
        }
        return ids;
    }

    /** String ids inside a plain string array (e.g. correctOptionIds). */
    protected Set<String> collectStringIds(JsonNode arr) {
        Set<String> ids = new HashSet<>();
        if (arr == null || !arr.isArray()) return ids;
        arr.forEach(n -> { if (n.isTextual()) ids.add(n.asText()); });
        return ids;
    }

    /** Check every id in `ids` belongs to `universe`; report those that do not. */
    protected void requireSubset(Set<String> ids, Set<String> universe, String path,
                                 String code, List<FieldError> errors) {
        for (String id : ids) {
            if (!universe.contains(id)) {
                errors.add(new FieldError(path, code, "unknown reference '" + id + "'"));
            }
        }
    }

    /** Integer field bounded [min, max] — retry budgets, thresholds. */
    protected void requireBoundedInt(JsonNode config, String field, String path,
                                     int min, int max, List<FieldError> errors) {
        if (config == null || !config.hasNonNull(field)) return;
        JsonNode v = config.get(field);
        if (!v.isInt() && !v.isLong()) {
            errors.add(new FieldError(path + ".config." + field, "INVALID_TYPE",
                    field + " must be an integer"));
            return;
        }
        int n = v.asInt();
        if (n < min || n > max) {
            errors.add(new FieldError(path + ".config." + field, "INVALID_VALUE",
                    field + " must be between " + min + " and " + max));
        }
    }

    /** Evidence refs usable at publish level. */
    protected void checkEvidenceRefs(JsonNode config, String field, String path,
                                     ValidationContext ctx, List<FieldError> errors) {
        if (!ctx.isPublish() || config == null) return;
        JsonNode arr = config.get(field);
        if (arr == null || !arr.isArray()) return;
        for (int i = 0; i < arr.size(); i++) {
            String evId = arr.get(i).asText();
            if (!ctx.evidenceUsable(evId)) {
                errors.add(new FieldError(path + ".config." + field + "[" + i + "]",
                        "EVIDENCE_NOT_FOUND", "evidence '" + evId + "' not usable for this event"));
            }
        }
    }
}
