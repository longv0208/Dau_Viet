package com.dauviet.learning.api.dto;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.contract.LessonCompletion;
import com.fasterxml.jackson.databind.JsonNode;

/** Response of POST .../submissions — evaluation + next cursor + completion. */
public record SubmitActivityResponse(
        String status,
        ActivityResult evaluation,
        boolean activityCompleted,
        AttemptProgressResponse.Progress progress,
        Next next,
        LessonCompletion completion) {

    public record Next(String stageId, String activityId, String activityType,
                       JsonNode learnerConfig) {
    }
}
