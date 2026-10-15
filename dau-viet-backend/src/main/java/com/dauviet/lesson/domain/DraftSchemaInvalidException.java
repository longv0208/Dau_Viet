package com.dauviet.lesson.domain;

/** Draft JSONB content failed schema/shape validation. */
public class DraftSchemaInvalidException extends RuntimeException {
    public DraftSchemaInvalidException(String message) {
        super(message);
    }
}
