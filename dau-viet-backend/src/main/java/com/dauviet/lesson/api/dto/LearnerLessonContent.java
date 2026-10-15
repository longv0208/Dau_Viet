package com.dauviet.lesson.api.dto;

import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

/** Learner-safe projected content of a published version (or a draft preview). */
public record LearnerLessonContent(
        UUID lessonId,
        UUID lessonVersionId,
        Integer versionNo,
        JsonNode content) {
}
