package com.dauviet.lesson.api.dto;

import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Payload for POST /api/v1/admin/lessons. `draftJson` is a raw JSONB object string. */
public record AdminLessonCreateRequest(
        @NotNull UUID eventId,
        @NotNull UUID templateId,
        @NotBlank @Size(max = 255) String title,
        @NotBlank String centralQuestion,
        String objectivesJson,
        String draftJson
) {
}
