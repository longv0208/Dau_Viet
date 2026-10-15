package com.dauviet.learning.api.dto;

import java.util.UUID;

import com.dauviet.learning.contract.LessonCompletion;

/** Response of GET /attempts/{id} — cursor + progress + completion verdict. */
public record AttemptProgressResponse(
        UUID attemptId,
        UUID lessonVersionId,
        String status,
        String currentStageId,
        String currentActivityId,
        Progress progress,
        LessonCompletion completion) {

    public record Progress(int completedRequired, int totalRequired) {
    }
}
