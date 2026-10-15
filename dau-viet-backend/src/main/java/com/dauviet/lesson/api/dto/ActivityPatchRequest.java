package com.dauviet.lesson.api.dto;

import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;

/** Partial update of an activity (type and id immutable). */
public record ActivityPatchRequest(
        Boolean required,
        String instruction,
        JsonNode config,
        JsonNode validation,
        JsonNode feedback,
        List<String> evidenceRefs,
        Long expectedRowVersion) {
}
