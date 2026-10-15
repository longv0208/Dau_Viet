package com.dauviet.lesson.api.dto;

import java.time.Instant;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

/** Full admin view of one published version — includes server-only keys. */
public record LessonVersionDetail(
        UUID id,
        UUID lessonId,
        int versionNo,
        int schemaVersion,
        Instant publishedAt,
        UUID publishedBy,
        JsonNode snapshot) {
}
