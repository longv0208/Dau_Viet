package com.dauviet.lesson.api.dto;

import java.time.Instant;
import java.util.UUID;

import com.dauviet.common.heritage.HeritageBackgroundConfigDto;
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
        String coverImageUrl,
        HeritageBackgroundConfigDto backgroundConfig) {
    public LearnerLessonMetadata(
            UUID id,
            String title,
            String centralQuestion,
            UUID eventId,
            UUID currentVersionId,
            int versionNo,
            Instant publishedAt) {
        this(id, title, centralQuestion, eventId, currentVersionId, versionNo, publishedAt,
                null, null, HeritageBackgroundConfigDto.defaultConfig());
    }

    public LearnerLessonMetadata(
            UUID id,
            String title,
            String centralQuestion,
            UUID eventId,
            UUID currentVersionId,
            int versionNo,
            Instant publishedAt,
            UUID coverAssetId,
            String coverImageUrl) {
        this(id, title, centralQuestion, eventId, currentVersionId, versionNo, publishedAt,
                coverAssetId, coverImageUrl, HeritageBackgroundConfigDto.defaultConfig());
    }
}
