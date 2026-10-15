package com.dauviet.lesson.api.dto;

import java.time.Instant;
import java.util.UUID;

/** One row of the admin version list. */
public record LessonVersionSummary(
        UUID id,
        int versionNo,
        int schemaVersion,
        Instant publishedAt,
        UUID publishedBy) {
}
