package com.dauviet.path.domain;

public class LessonLockedByPathException extends RuntimeException {
    public LessonLockedByPathException(String message) { super(message); }
}
