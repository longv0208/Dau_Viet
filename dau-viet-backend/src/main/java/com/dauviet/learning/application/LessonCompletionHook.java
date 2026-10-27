package com.dauviet.learning.application;

import java.util.List;
import java.util.UUID;

import com.dauviet.learning.api.dto.CompleteAttemptResponse;

/**
 * Extension hook invoked inside {@link LearnerAttemptService} within the same
 * transaction when an attempt transitions to {@code COMPLETED}.
 */
public interface LessonCompletionHook {

    default List<CompleteAttemptResponse.UnlockedLocationCue> onLessonCompleted(
            UUID userId, UUID lessonId, UUID attemptId) {
        return List.of();
    }
}
