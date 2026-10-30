package com.dauviet.historicalevent.admin.dto;

import java.util.List;

import com.dauviet.common.heritage.HeritageBackgroundConfigDto;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Payload for POST /api/v1/admin/events. */
public record AdminEventCreateRequest(
        @NotBlank @Size(max = 150)
        @Pattern(regexp = "^[a-z0-9]+(?:-[a-z0-9]+)*$",
                 message = "slug must be lowercase kebab-case")
        String slug,

        @NotBlank @Size(max = 255) String title,
        @Size(max = 100) String era,
        @Size(max = 100) String period,
        Integer startYear,
        @NotBlank String summary,
        String description,
        String location,
        @Size(max = 512) String coverAssetKey,
        List<String> tags,
        HeritageBackgroundConfigDto backgroundConfig
) {
    public AdminEventCreateRequest(
            String slug,
            String title,
            String era,
            String period,
            Integer startYear,
            String summary,
            String description,
            String location,
            String coverAssetKey,
            List<String> tags) {
        this(slug, title, era, period, startYear, summary, description, location, coverAssetKey, tags, null);
    }
}
