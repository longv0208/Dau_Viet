package com.dauviet.historicalevent.admin.dto;

import java.util.List;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * PATCH body for /api/v1/admin/events/{id}. Null fields are left unchanged.
 * `slug` is ignored once the event is PUBLISHED (enforced in service).
 * `expectedRowVersion` performs the optimistic-lock check when provided.
 */
public record AdminEventUpdateRequest(
        @Size(max = 150)
        @Pattern(regexp = "^[a-z0-9]+(?:-[a-z0-9]+)*$",
                 message = "slug must be lowercase kebab-case")
        String slug,

        @Size(max = 255) String title,
        @Size(max = 100) String era,
        @Size(max = 100) String period,
        Integer startYear,
        String summary,
        String description,
        String location,
        @Size(max = 512) String coverAssetKey,
        List<String> tags,
        Long expectedRowVersion
) {
}
