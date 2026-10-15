package com.dauviet.lesson.domain;

/**
 * Raised at publish-readiness when the lesson's template schema_version
 * does not support the draft schemaVersion being validated.
 */
public class TemplateSchemaMismatchException extends RuntimeException {
    public TemplateSchemaMismatchException(String message) { super(message); }
}
