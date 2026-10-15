package com.dauviet.lesson.api.dto;

import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;

import jakarta.validation.constraints.NotBlank;

/** Create an activity inside a stage; id optional. */
public record ActivityUpsertRequest(
        String id,
        @NotBlank String type,
        Boolean required,
        String instruction,
        JsonNode config,
        JsonNode validation,
        JsonNode feedback,
        List<String> evidenceRefs,
        Integer position,
        Long expectedRowVersion) {
}
