package com.dauviet.lesson.api.dto;

import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;

/** One activity inside a draft stage. */
public record ActivityDto(
        String id,
        String type,
        Boolean required,
        String instruction,
        JsonNode config,
        JsonNode validation,
        JsonNode feedback,
        List<String> evidenceRefs) {
}
