package com.dauviet.map.admin.dto;

import java.util.UUID;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Create/update payload for one map location. `eventId` comes from the path
 * (nested under /admin/events/{eventId}/map-locations); `unlockLessonId`
 * nullable — null means always AVAILABLE.
 */
public record AdminMapLocationRequest(
        @NotBlank @Size(max = 255) String title,
        @Size(max = 4000) String description,
        @NotNull @DecimalMin("-90") @DecimalMax("90") Double latitude,
        @NotNull @DecimalMin("-180") @DecimalMax("180") Double longitude,
        UUID unlockLessonId,
        Integer displayOrder
) {
}
