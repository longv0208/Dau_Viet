package com.dauviet.lesson.api.dto;

import java.time.Instant;
import java.util.UUID;

/** Read-only lesson template payload. presetJson is the raw JSONB string. */
public record LessonTemplateResponse(
        UUID id,
        String code,
        String name,
        String description,
        Integer schemaVersion,
        String presetJson,
        Boolean enabled,
        Instant createdAt,
        Instant updatedAt
) {
}
