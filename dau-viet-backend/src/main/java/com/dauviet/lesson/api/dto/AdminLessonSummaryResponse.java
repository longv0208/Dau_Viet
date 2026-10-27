package com.dauviet.lesson.api.dto;

import java.util.UUID;

/** Compact lesson row for admin list views. */
public record AdminLessonSummaryResponse(
        UUID id,
        UUID eventId,
        String title,
        String status,
        UUID currentVersionId,
        UUID coverAssetId,
        Long rowVersion
) {
    public AdminLessonSummaryResponse(
            UUID id,
            UUID eventId,
            String title,
            String status,
            UUID currentVersionId,
            Long rowVersion) {
        this(id, eventId, title, status, currentVersionId, null, rowVersion);
    }
}
