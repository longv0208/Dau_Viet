package com.dauviet.learning.contract;

import com.fasterxml.jackson.databind.JsonNode;

/** Verdict of the published completion config against the attempt state. */
public record LessonCompletion(
        boolean complete,
        String reason,
        JsonNode detail) {

    public static final String ALL_REQUIRED_STAGES = "ALL_REQUIRED_STAGES";
    public static final String REQUIRED_STAGE_IDS = "REQUIRED_STAGE_IDS";
    public static final String MIN_SCORE = "MIN_SCORE";
    public static final String DEFAULT_ALL_REQUIRED = "DEFAULT_ALL_REQUIRED";
    public static final String NOT_COMPLETE = "NOT_COMPLETE";
}
