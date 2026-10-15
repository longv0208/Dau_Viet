package com.dauviet.learning.domain;

/** activity is not the current executable activity. */
public class ActivityNotAvailableException extends RuntimeException {
    public ActivityNotAvailableException(String message) {
        super(message);
    }
}