package com.dauviet.learning.domain;

/** attempt belongs to another user. */
public class AttemptNotOwnedException extends RuntimeException {
    public AttemptNotOwnedException(String message) {
        super(message);
    }
}