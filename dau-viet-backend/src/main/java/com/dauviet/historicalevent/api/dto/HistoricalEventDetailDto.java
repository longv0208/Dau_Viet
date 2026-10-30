package com.dauviet.historicalevent.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import com.dauviet.common.heritage.HeritageBackgroundConfigDto;

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
        Instant publishedAt,
        HeritageBackgroundConfigDto backgroundConfig
) {
    public HistoricalEventDetailDto(
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
            Instant publishedAt) {
        this(id, slug, title, era, period, startYear, summary, description, location,
                coverAssetKey, tags, publishedAt, HeritageBackgroundConfigDto.defaultConfig());
    }
}
