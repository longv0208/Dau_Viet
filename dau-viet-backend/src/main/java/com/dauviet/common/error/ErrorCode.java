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
    INTERNAL_ERROR
}
