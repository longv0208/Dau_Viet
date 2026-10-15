package com.dauviet.common.error;

/**
 * Stable machine-readable error codes exposed to clients.
 * Keep in sync with docs/API_SPEC.md error contract.
 */
public enum ErrorCode {
    VALIDATION_ERROR,
    MALFORMED_ID,
    NOT_FOUND,
    EVENT_NOT_FOUND,
    METHOD_NOT_ALLOWED,
    UNAUTHORIZED,
    FORBIDDEN,
    EMAIL_TAKEN,
    INVALID_CREDENTIALS,
    INVALID_STATUS_TRANSITION,
    EVENT_IN_USE,
    LESSON_NOT_FOUND,
    TEMPLATE_NOT_FOUND,
    TEMPLATE_DISABLED,
    LESSON_VERSION_IMMUTABLE,
    DRAFT_SCHEMA_INVALID,
    OPTIMISTIC_LOCK_CONFLICT,
    INTERNAL_ERROR
}
