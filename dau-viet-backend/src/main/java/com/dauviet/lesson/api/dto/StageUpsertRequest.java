package com.dauviet.lesson.api.dto;

import java.util.List;

import jakarta.validation.constraints.NotBlank;

/** Create a stage; id optional (auto-generated when absent). */
public record StageUpsertRequest(
        String id,
        @NotBlank String type,
        String title,
        Boolean required,
        List<String> nextStageIds,
        Integer position,
        Long expectedRowVersion) {
}
