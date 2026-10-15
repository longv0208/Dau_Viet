package com.dauviet.lesson.domain;

/** Requested lesson template id does not exist. */
public class TemplateNotFoundException extends RuntimeException {
    public TemplateNotFoundException(String message) {
        super(message);
    }
}
