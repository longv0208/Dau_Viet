package com.dauviet.lesson.api.dto;

import java.util.UUID;

/** One published lesson row in the public event lesson list. */
public record LearnerLessonListItem(
        UUID id,
        String title,
        String centralQuestion,
        UUID coverAssetId,
        String coverImageUrl) {
    public LearnerLessonListItem(
            UUID id,
            String title,
            String centralQuestion) {
        this(id, title, centralQuestion, null, null);
    }
}
