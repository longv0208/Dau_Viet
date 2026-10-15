package com.dauviet.lesson.domain;

/** Lesson exists but has no published version learners can read. */
public class LessonNotPublishedException extends RuntimeException {
    public LessonNotPublishedException(String message) {
        super(message);
    }
}
