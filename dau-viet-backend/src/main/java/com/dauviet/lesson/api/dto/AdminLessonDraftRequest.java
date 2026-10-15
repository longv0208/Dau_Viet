package com.dauviet.lesson.api.dto;

import jakarta.validation.constraints.NotNull;

/** PUT body for /api/v1/admin/lessons/{id}/draft — replaces draft_json wholesale. */
public record AdminLessonDraftRequest(
        @NotNull String draftJson,
        Long expectedRowVersion
) {
}
