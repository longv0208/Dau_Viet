package com.dauviet.historicalevent.admin.mapper;

import java.util.List;

import org.springframework.stereotype.Component;

import com.dauviet.historicalevent.admin.dto.AdminEventResponse;
import com.dauviet.historicalevent.admin.dto.AdminEventSummaryResponse;
import com.dauviet.historicalevent.domain.HistoricalEvent;

/** Entity → admin DTO mapping. */
@Component
public class AdminEventMapper {

    public AdminEventResponse toResponse(HistoricalEvent e) {
        return new AdminEventResponse(
                e.getId(), e.getSlug(), e.getTitle(), e.getEra(), e.getPeriod(),
                e.getStartYear(), e.getSummary(), e.getDescription(),
                e.getLocation(), e.getCoverAssetKey(), copyTags(e),
                e.getStatus().name(), e.getRowVersion(),
                e.getCreatedAt(), e.getUpdatedAt(), e.getBackgroundConfig());
    }

    public AdminEventSummaryResponse toSummary(HistoricalEvent e) {
        return new AdminEventSummaryResponse(
                e.getId(), e.getSlug(), e.getTitle(), e.getEra(),
                e.getStartYear(), e.getStatus().name(), copyTags(e));
    }

    private List<String> copyTags(HistoricalEvent e) {
        return e.getTags() == null ? List.of() : List.copyOf(e.getTags());
    }
}
