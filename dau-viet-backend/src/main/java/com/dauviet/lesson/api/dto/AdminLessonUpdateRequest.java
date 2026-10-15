package com.dauviet.lesson.api.dto;

import java.util.UUID;

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
        Long expectedRowVersion
) {
}
