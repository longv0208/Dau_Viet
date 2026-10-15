package com.dauviet.learning.contract;

import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

/** One learner submission for the current activity. */
public record ActivitySubmission(
        UUID attemptId,
        String activityId,
        JsonNode answer,
        String idempotencyKey) {
}
