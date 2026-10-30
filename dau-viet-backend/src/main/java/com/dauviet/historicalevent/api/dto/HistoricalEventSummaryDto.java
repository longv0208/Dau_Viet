package com.dauviet.historicalevent.api.dto;

import java.util.List;
import java.util.UUID;
import com.dauviet.common.heritage.HeritageBackgroundConfigDto;

/**
 * Learner-facing summary for list views (timeline, explore).
 * Excludes internal fields; only PUBLISHED rows reach this DTO.
 */
public record HistoricalEventSummaryDto(
        UUID id,
        String slug,
        String title,
        String era,
        String period,
        Integer startYear,
        String summary,
        String coverAssetKey,
        List<String> tags,
        HeritageBackgroundConfigDto backgroundConfig
) {
    public HistoricalEventSummaryDto(
            UUID id,
            String slug,
            String title,
            String era,
            String period,
            Integer startYear,
            String summary,
            String coverAssetKey,
            List<String> tags) {
        this(id, slug, title, era, period, startYear, summary, coverAssetKey, tags,
                HeritageBackgroundConfigDto.defaultConfig());
    }
}
