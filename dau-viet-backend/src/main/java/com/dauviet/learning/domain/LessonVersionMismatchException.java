package com.dauviet.learning.domain;

/** pinned lesson version cannot be resolved. */
public class LessonVersionMismatchException extends RuntimeException {
    public LessonVersionMismatchException(String message) {
        super(message);
    }
}