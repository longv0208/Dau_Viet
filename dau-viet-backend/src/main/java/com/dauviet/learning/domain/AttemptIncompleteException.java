package com.dauviet.learning.domain;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * POST /complete was called while the completion evaluator still reports
 * the attempt incomplete -> 409 ATTEMPT_NOT_COMPLETE with the verdict
 * detail; nothing is flipped.
 */
public class AttemptIncompleteException extends RuntimeException {

    private final transient JsonNode detail;

    public AttemptIncompleteException(String message, JsonNode detail) {
        super(message);
        this.detail = detail;
    }

    public JsonNode getDetail() { return detail; }
}
