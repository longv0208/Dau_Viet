package com.dauviet.lesson.api.dto;

import java.util.UUID;

import com.dauviet.common.heritage.HeritageBackgroundConfigDto;
/** One published lesson row in the public event lesson list. */
public record LearnerLessonListItem(
        UUID id,
        String title,
        String centralQuestion,
        UUID coverAssetId,
        String coverImageUrl,
        HeritageBackgroundConfigDto backgroundConfig) {
    public LearnerLessonListItem(
            UUID id,
            String title,
            String centralQuestion) {
        this(id, title, centralQuestion, null, null, HeritageBackgroundConfigDto.defaultConfig());
    }

    public LearnerLessonListItem(
            UUID id,
            String title,
            String centralQuestion,
            UUID coverAssetId,
            String coverImageUrl) {
        this(id, title, centralQuestion, coverAssetId, coverImageUrl, HeritageBackgroundConfigDto.defaultConfig());
    }
}
