package com.dauviet.lesson.api.dto;

import jakarta.validation.constraints.Size;

/**
 * Payload for PATCH /api/v1/admin/lesson-templates/{id}.
 * Null fields are left unchanged. `code` is immutable — it is the stable
 * identifier the authoring flow and seeds key on, so it is not updatable.
 */
public record AdminLessonTemplateUpdateRequest(
        @Size(max = 150) String name,
        String description,
        String presetJson,
        Boolean enabled
) {
}
