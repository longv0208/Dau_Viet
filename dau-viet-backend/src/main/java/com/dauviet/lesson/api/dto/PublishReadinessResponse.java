package com.dauviet.lesson.api.dto;

import java.util.List;
import java.util.Map;

/**
 * Result of POST /admin/lessons/{id}/validate — always HTTP 200.
 * `ready` is true only when errors is empty; warnings never block.
 */
public record PublishReadinessResponse(
        boolean ready,
        List<Map<String, String>> errors,
        List<Map<String, String>> warnings,
        Map<String, Object> summary) {
}
