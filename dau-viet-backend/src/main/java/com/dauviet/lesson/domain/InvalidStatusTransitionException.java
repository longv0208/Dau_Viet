package com.dauviet.lesson.domain;

/** Attempted a status change that is not allowed (e.g. PUBLISHED -> DRAFT). */
public class InvalidStatusTransitionException extends RuntimeException {
    public InvalidStatusTransitionException(String message) {
        super(message);
    }
}
