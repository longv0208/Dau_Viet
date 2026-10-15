package com.dauviet.lesson.api.dto;

import java.time.LocalDate;
import java.util.UUID;

import jakarta.validation.constraints.Size;

/**
 * Partial update of an evidence row. `eventId` is immutable;
 * `assetId` may be set or cleared (explicit null clears — send absent to keep).
 */
public record EvidencePatchRequest(
        @Size(max = 255) String title,
        @Size(max = 48) String evidenceType,
        String description,
        @Size(max = 255) String sourceTitle,
        @Size(max = 255) String sourceAuthor,
        String sourceUrl,
        String sourceCitation,
        LocalDate sourcePublishedAt,
        String reliability,
        String relevance,
        UUID assetId,
        Boolean clearAsset,
        Long expectedRowVersion) {
}
