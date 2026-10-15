package com.dauviet.learning.api.dto;

import com.fasterxml.jackson.databind.JsonNode;

import jakarta.validation.constraints.NotNull;

/** Body of POST /attempts/{id}/activities/{activityId}/submissions. */
public record SubmitActivityRequest(
        @NotNull(message = "answer is required")
        JsonNode answer) {
}
