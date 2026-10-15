package com.dauviet.learning.domain;

/** No persisted lesson_results row for this attempt yet -> 404. */
public class ResultNotFoundException extends RuntimeException {

    public ResultNotFoundException(String message) {
        super(message);
    }
}
