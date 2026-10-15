package com.dauviet.historicalevent.admin.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Admin-facing event payload — includes status + rowVersion (not exposed on
 * the public learner API).
 */
public record AdminEventResponse(
        UUID id,
        String slug,
        String title,
        String era,
        String period,
        Integer startYear,
        String summary,
        String description,
        String location,
        String coverAssetKey,
        List<String> tags,
        String status,
        Long rowVersion,
        Instant createdAt,
        Instant updatedAt
) {
}
