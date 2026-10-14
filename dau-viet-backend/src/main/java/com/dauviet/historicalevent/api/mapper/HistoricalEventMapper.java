package com.dauviet.historicalevent.api.mapper;

import java.util.List;

import org.springframework.stereotype.Component;

import com.dauviet.historicalevent.api.dto.HistoricalEventDetailDto;
import com.dauviet.historicalevent.api.dto.HistoricalEventSummaryDto;
import com.dauviet.historicalevent.domain.HistoricalEvent;

/**
 * Entity → learner-safe DTO mapping. Deliberately plain Java — no MapStruct —
 * because only two projections exist today.
 */
@Component
public class HistoricalEventMapper {

    public HistoricalEventSummaryDto toSummaryDto(HistoricalEvent e) {
        return new HistoricalEventSummaryDto(
                e.getId(),
                e.getSlug(),
                e.getTitle(),
                e.getEra(),
                e.getPeriod(),
                e.getStartYear(),
                e.getSummary(),
                e.getCoverAssetKey(),
                copyTags(e)
        );
    }

    public HistoricalEventDetailDto toDetailDto(HistoricalEvent e) {
        return new HistoricalEventDetailDto(
                e.getId(),
                e.getSlug(),
                e.getTitle(),
                e.getEra(),
                e.getPeriod(),
                e.getStartYear(),
                e.getSummary(),
                e.getDescription(),
                e.getLocation(),
                e.getCoverAssetKey(),
                copyTags(e),
                null // publishedAt reserved; not populated until lesson_versions exist
        );
    }

    private List<String> copyTags(HistoricalEvent e) {
        return e.getTags() == null ? List.of() : List.copyOf(e.getTags());
    }
}
