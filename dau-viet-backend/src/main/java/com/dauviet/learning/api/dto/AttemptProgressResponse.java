package com.dauviet.learning.api.dto;

import java.util.List;
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
        LessonCompletion completion,
        List<String> completedActivityIds,
        CurrentActivityResponse.StepProgress stepProgress) {

    public AttemptProgressResponse(
            UUID attemptId,
            UUID lessonVersionId,
            String status,
            String currentStageId,
            String currentActivityId,
            Progress progress,
            LessonCompletion completion) {
        this(attemptId, lessonVersionId, status, currentStageId, currentActivityId,
                progress, completion, List.of(), null);
    }

    public record Progress(int completedRequired, int totalRequired) {
    }
}
