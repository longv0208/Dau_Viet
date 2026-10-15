package com.dauviet.lesson.api.dto;

import java.util.List;

/** Partial update of a stage (type and id immutable). */
public record StagePatchRequest(
        String title,
        Boolean required,
        List<String> nextStageIds,
        List<String> requiredEvidenceIds,
        Long expectedRowVersion) {
}
