package com.dauviet.lesson.draft.validators;

import java.util.List;
import java.util.Set;

import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.JsonNode;

import com.dauviet.lesson.draft.ActivityType;
import com.dauviet.lesson.draft.FieldError;
import com.dauviet.lesson.draft.ValidationContext;

/**
 * MULTIPLE_CHOICE: question + >=2 options with unique ids, and exactly
 * one non-empty correct-id collection that is a subset of option ids.
 * correctOptionIds/multiCorrect live in config but are SERVER_ONLY keys.
 */
@Component
public class MultipleChoiceValidator extends AbstractActivityValidator {

    @Override public ActivityType supports() { return ActivityType.MULTIPLE_CHOICE; }

    @Override
    public void validate(JsonNode activity, String path, ValidationContext ctx,
                         List<FieldError> errors) {
        JsonNode config = config(activity);
        if (config == null) {
            errors.add(new FieldError(path + ".config", "MISSING_FIELD", "config is required"));
            return;
        }
        requireField(config, "question", path, errors);
        requireNonEmptyArray(config, "options", path, 2, errors);
        if (!config.has("options") || !config.get("options").isArray()) return;

        Set<String> optionIds = collectIds(config.get("options"),
                path + ".config.options", errors);

        // Accept either correctOptionIds (single/multi) or multiCorrect; not both.
        JsonNode correct = config.get("correctOptionIds");
        JsonNode multi = config.get("multiCorrect");
        boolean hasCorrect = correct != null && correct.isArray() && !correct.isEmpty();
        boolean hasMulti = multi != null && multi.isArray() && !multi.isEmpty();
        if (hasCorrect && hasMulti) {
            errors.add(new FieldError(path + ".config", "INVALID_CONFIG",
                    "use only one of correctOptionIds or multiCorrect"));
        } else if (!hasCorrect && !hasMulti && ctx.isPublish()) {
            errors.add(new FieldError(path + ".config", "MISSING_FIELD",
                    "one of correctOptionIds / multiCorrect is required"));
        }
        JsonNode chosen = hasCorrect ? correct : multi;
        if (chosen != null && chosen.isArray()) {
            requireSubset(collectStringIds(chosen), optionIds,
                    path + ".config." + (hasCorrect ? "correctOptionIds" : "multiCorrect"),
                    "INVALID_CONFIG", errors);
        }
        requireBoundedInt(config, "maxAttempts", path, 1, 20, errors);
    }
}
