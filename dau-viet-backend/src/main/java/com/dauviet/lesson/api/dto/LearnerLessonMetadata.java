package com.dauviet.lesson.api.dto;

import java.time.Instant;
import java.util.UUID;

/** Public lesson metadata — presentation-safe only. */
public record LearnerLessonMetadata(
        UUID id,
        String title,
        String centralQuestion,
        UUID eventId,
        UUID currentVersionId,
        int versionNo,
        Instant publishedAt,
        UUID coverAssetId,
        String coverImageUrl) {
    public LearnerLessonMetadata(
            UUID id,
            String title,
            String centralQuestion,
            UUID eventId,
            UUID currentVersionId,
            int versionNo,
            Instant publishedAt) {
        this(id, title, centralQuestion, eventId, currentVersionId, versionNo, publishedAt, null, null);
    }
}
