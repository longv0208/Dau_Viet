package com.dauviet.lesson.domain;

/** A lesson template with this code already exists. */
public class TemplateCodeTakenException extends RuntimeException {
    public TemplateCodeTakenException(String message) {
        super(message);
    }
}
