package com.dauviet.lesson.api.dto;

import java.time.Instant;
import java.util.UUID;

/** Result of a successful publish. */
public record PublishResponse(
        UUID lessonId,
        UUID lessonVersionId,
        int versionNo,
        String status,
        Instant publishedAt) {
}
