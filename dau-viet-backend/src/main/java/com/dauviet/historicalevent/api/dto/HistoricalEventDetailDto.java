package com.dauviet.historicalevent.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Learner-facing detail for a single published event.
 */
public record HistoricalEventDetailDto(
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
        Instant publishedAt
) {
}
