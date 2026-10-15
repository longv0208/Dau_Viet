package com.dauviet.lesson.api.dto;

import java.time.LocalDate;
import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Create an evidence row bound to an event. */
public record EvidenceUpsertRequest(
        @NotNull UUID eventId,
        @NotBlank @Size(max = 255) String title,
        @NotBlank @Size(max = 48) String evidenceType,
        String description,
        @NotBlank @Size(max = 255) String sourceTitle,
        @Size(max = 255) String sourceAuthor,
        String sourceUrl,
        String sourceCitation,
        LocalDate sourcePublishedAt,
        String reliability,
        String relevance,
        UUID assetId) {
}
