package com.dauviet.lesson.domain;

/** Operation blocked because the event still has non-archived lessons. */
public class EventInUseException extends RuntimeException {
    public EventInUseException(String message) {
        super(message);
    }
}
