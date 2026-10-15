package com.dauviet.lesson.api.dto;

import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;

/** One stage inside the lesson draft. */
public record StageDto(
        String id,
        String type,
        String title,
        Boolean required,
        List<JsonNode> activities,
        List<String> nextStageIds,
        List<String> requiredEvidenceIds) {
}
