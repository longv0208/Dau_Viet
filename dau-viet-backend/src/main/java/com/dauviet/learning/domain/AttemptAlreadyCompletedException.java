package com.dauviet.learning.domain;

/** attempt already completed. */
public class AttemptAlreadyCompletedException extends RuntimeException {
    public AttemptAlreadyCompletedException(String message) {
        super(message);
    }
}