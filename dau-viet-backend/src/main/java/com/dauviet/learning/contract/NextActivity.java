package com.dauviet.learning.contract;

import com.fasterxml.jackson.databind.JsonNode;

/** Pointer to the next executable activity, with its learner-safe config. */
public record NextActivity(
        String stageId,
        String activityId,
        String activityType,
        JsonNode learnerConfig) {
}
