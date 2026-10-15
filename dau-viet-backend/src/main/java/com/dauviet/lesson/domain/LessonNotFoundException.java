package com.dauviet.lesson.domain;

/** Requested lesson id does not exist. */
public class LessonNotFoundException extends RuntimeException {
    public LessonNotFoundException(String message) {
        super(message);
    }
}
