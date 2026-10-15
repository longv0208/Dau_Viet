package com.dauviet.learning.domain;

/** attempt is not in progress. */
public class AttemptNotInProgressException extends RuntimeException {
    public AttemptNotInProgressException(String message) {
        super(message);
    }
}