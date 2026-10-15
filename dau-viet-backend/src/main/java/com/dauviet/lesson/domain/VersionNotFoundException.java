package com.dauviet.lesson.domain;

/** Requested lesson_versions row does not exist for the lesson. */
public class VersionNotFoundException extends RuntimeException {
    public VersionNotFoundException(String message) {
        super(message);
    }
}
