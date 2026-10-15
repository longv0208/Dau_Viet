package com.dauviet.lesson.draft;

import java.util.List;

/**
 * Thrown when a mutation produces SAVE-level draft errors that must
 * abort the write. Carries the ordered field-error list for the CMS.
 * Mapped to 422 DRAFT_SCHEMA_INVALID with details.errors.
 */
public class DraftValidationException extends RuntimeException {

    private final List<FieldError> errors;

    public DraftValidationException(List<FieldError> errors) {
        super("draft validation failed: " + errors.size() + " error(s)");
        this.errors = List.copyOf(errors);
    }

    public List<FieldError> getErrors() {
        return errors;
    }
}
