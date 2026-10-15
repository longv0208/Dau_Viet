package com.dauviet.lesson.api.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record EvidenceResponse(
        UUID id,
        UUID eventId,
        String title,
        String evidenceType,
        String description,
        String sourceTitle,
        String sourceAuthor,
        String sourceUrl,
        String sourceCitation,
        LocalDate sourcePublishedAt,
        String reliability,
        String relevance,
        UUID assetId,
        String status,
        UUID createdBy,
        Instant createdAt,
        Instant updatedAt,
        Long rowVersion) {
}
