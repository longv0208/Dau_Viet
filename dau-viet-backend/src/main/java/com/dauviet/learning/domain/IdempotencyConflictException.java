package com.dauviet.learning.domain;

/** Idempotency-Key reused with a different request payload -> 409. */
public class IdempotencyConflictException extends RuntimeException {

    public IdempotencyConflictException(String message) {
        super(message);
    }
}
