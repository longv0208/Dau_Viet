package com.dauviet.learning.handler;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.contract.ActivitySubmission;
import com.dauviet.learning.contract.AttemptContext;
import com.dauviet.lesson.draft.ActivityType;

/**
 * Runtime evaluator for one ActivityType — mirrors the
 * ActivityConfigValidator SPI (supports() + registry). Pure function over
 * the pinned snapshot: no persistence inside handlers.
 */
public interface ActivityHandler {

    ActivityType supports();

    /**
     * Evaluate a submission against the activity definition inside the
     * pinned snapshot. Must not throw for bad learner input — malformed
     * answers surface as IllegalArgumentException -> 400 VALIDATION_ERROR.
     * Emitted output/feedback must contain no LEARNER_HIDDEN_KEYS.
     */
    ActivityResult evaluate(AttemptContext ctx, ActivitySubmission submission);
}
