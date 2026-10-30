package com.dauviet.lesson.api.dto;

import java.util.UUID;

import com.dauviet.common.heritage.HeritageBackgroundConfigDto;
import jakarta.validation.constraints.Size;

/**
 * PATCH body for /api/v1/admin/lessons/{id}. Null fields are left unchanged.
 * `expectedRowVersion` performs the optimistic-lock check when provided.
 */
public record AdminLessonUpdateRequest(
        UUID templateId,
        @Size(max = 255) String title,
        String centralQuestion,
        String objectivesJson,
        Long expectedRowVersion,
        UUID coverAssetId,
        Boolean clearCoverAsset,
        HeritageBackgroundConfigDto backgroundConfig,
        Boolean clearBackgroundConfig
) {
    public AdminLessonUpdateRequest(
            UUID templateId,
            String title,
            String centralQuestion,
            String objectivesJson,
            Long expectedRowVersion) {
        this(templateId, title, centralQuestion, objectivesJson, expectedRowVersion, null, null, null, null);
    }

    public AdminLessonUpdateRequest(
            UUID templateId,
            String title,
            String centralQuestion,
            String objectivesJson,
            Long expectedRowVersion,
            UUID coverAssetId,
            Boolean clearCoverAsset) {
        this(templateId, title, centralQuestion, objectivesJson, expectedRowVersion, coverAssetId, clearCoverAsset, null, null);
    }
}
