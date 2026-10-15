package com.dauviet.learning.contract;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * Learner-safe evaluation result of one submission. `output` is persisted
 * into AttemptState.outputs (drives VERIFICATION / completion); `feedbackCode`
 * references a key inside the activity's authored `feedback` object — never
 * the answer itself. `completed` decides whether the activity counts toward
 * stage/lesson completion.
 */
public record ActivityResult(
        String outcome,
        boolean completed,
        JsonNode output,
        String feedbackCode) {

    public static final String COMPLETED = "COMPLETED";
    public static final String INCORRECT = "INCORRECT";
    public static final String IN_PROGRESS = "IN_PROGRESS";
    public static final String SUPPORTED = "SUPPORTED";
    public static final String PARTIAL = "PARTIAL";
    public static final String CONTRADICTED = "CONTRADICTED";
}
