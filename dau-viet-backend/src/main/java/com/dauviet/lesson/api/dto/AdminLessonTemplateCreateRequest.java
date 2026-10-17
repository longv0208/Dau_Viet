package com.dauviet.lesson.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Payload for POST /api/v1/admin/lesson-templates.
 * `presetJson` is a raw JSONB object string holding the stage skeleton
 * (schemaVersion + stages[] + optional completion/objectives).
 */
public record AdminLessonTemplateCreateRequest(
        @NotBlank @Size(max = 64) String code,
        @NotBlank @Size(max = 150) String name,
        String description,
        @NotBlank String presetJson
) {
}
