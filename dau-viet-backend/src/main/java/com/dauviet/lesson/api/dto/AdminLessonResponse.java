package com.dauviet.lesson.api.dto;

import java.time.Instant;
import java.util.UUID;

/** Admin-facing lesson payload. draftJson/objectivesJson surface as raw JSONB strings. */
public record AdminLessonResponse(
        UUID id,
        UUID eventId,
        UUID templateId,
        String title,
        String centralQuestion,
        String objectivesJson,
        String draftJson,
        String status,
        UUID currentVersionId,
        UUID coverAssetId,
        Long rowVersion,
        UUID createdBy,
        UUID updatedBy,
        Instant createdAt,
        Instant updatedAt
) {
    public AdminLessonResponse(
            UUID id,
            UUID eventId,
            UUID templateId,
            String title,
            String centralQuestion,
            String objectivesJson,
            String draftJson,
            String status,
            UUID currentVersionId,
            Long rowVersion,
            UUID createdBy,
            UUID updatedBy,
            Instant createdAt,
            Instant updatedAt) {
        this(id, eventId, templateId, title, centralQuestion, objectivesJson, draftJson,
                status, currentVersionId, null, rowVersion, createdBy, updatedBy, createdAt, updatedAt);
    }
}
