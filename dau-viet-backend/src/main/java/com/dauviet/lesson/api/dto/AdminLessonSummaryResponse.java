package com.dauviet.lesson.api.dto;

import java.util.UUID;

/** Compact lesson row for admin list views. */
public record AdminLessonSummaryResponse(
        UUID id,
        UUID eventId,
        String title,
        String status,
        UUID currentVersionId,
        Long rowVersion
) {
}
