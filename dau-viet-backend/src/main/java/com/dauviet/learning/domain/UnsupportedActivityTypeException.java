package com.dauviet.learning.domain;

/** no handler registered for this activity type. */
public class UnsupportedActivityTypeException extends RuntimeException {
    public UnsupportedActivityTypeException(String message) {
        super(message);
    }
}