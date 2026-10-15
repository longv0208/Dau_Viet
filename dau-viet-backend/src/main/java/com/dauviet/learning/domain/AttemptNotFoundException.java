package com.dauviet.learning.domain;

/** attempt does not exist. */
public class AttemptNotFoundException extends RuntimeException {
    public AttemptNotFoundException(String message) {
        super(message);
    }
}