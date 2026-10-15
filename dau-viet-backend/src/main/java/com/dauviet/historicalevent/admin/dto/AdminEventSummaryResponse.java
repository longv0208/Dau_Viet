package com.dauviet.historicalevent.admin.dto;

import java.util.List;
import java.util.UUID;

/** Compact event row for admin list views. */
public record AdminEventSummaryResponse(
        UUID id,
        String slug,
        String title,
        String era,
        Integer startYear,
        String status,
        List<String> tags
) {
}
