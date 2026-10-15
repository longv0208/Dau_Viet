package com.dauviet.lesson.domain;

/** Template exists but is disabled — cannot back a new lesson. */
public class TemplateDisabledException extends RuntimeException {
    public TemplateDisabledException(String message) {
        super(message);
    }
}
