package com.dauviet.energy.api.dto;

import java.time.Instant;
import java.util.UUID;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * DTOs cho Admin API /api/v1/admin/energy/* (GAME-07 Phase 3).
 */
public final class AdminEnergyDtos {

    private AdminEnergyDtos() {
    }

    /** GET/PUT /admin/energy/settings — quy tắc Thể lực toàn cục. */
    public record AdminEnergySettingsResponse(
            boolean enabled,
            int maxEnergy,
            int incorrectPenalty,
            int recoveryAmount,
            int recoveryIntervalSeconds,
            Instant updatedAt,
            UUID updatedBy,
            Long rowVersion) {
    }

    /**
     * PUT /admin/energy/settings — toàn bộ trường bắt buộc (PUT full
     * replace). Ràng buộc khớp CHECK constraint V49 — sai → 400 rõ
     * thay vì DB exception.
     */
    public record UpdateEnergySettingsRequest(
            @NotNull(message = "enabled is required")
            Boolean enabled,

            @NotNull(message = "maxEnergy is required")
            @Min(value = 1, message = "maxEnergy must be between 1 and 100")
            @Max(value = 100, message = "maxEnergy must be between 1 and 100")
            Integer maxEnergy,

            @NotNull(message = "incorrectPenalty is required")
            @Min(value = 1, message = "incorrectPenalty must be between 1 and 100")
            @Max(value = 100, message = "incorrectPenalty must be between 1 and 100")
            Integer incorrectPenalty,

            @NotNull(message = "recoveryAmount is required")
            @Min(value = 1, message = "recoveryAmount must be between 1 and 100")
            @Max(value = 100, message = "recoveryAmount must be between 1 and 100")
            Integer recoveryAmount,

            @NotNull(message = "recoveryIntervalSeconds is required")
            @Min(value = 60, message = "recoveryIntervalSeconds must be between 60 and 86400")
            @Max(value = 86400, message = "recoveryIntervalSeconds must be between 60 and 86400")
            Integer recoveryIntervalSeconds) {
    }

    /** GET /admin/energy/remedies — một remedy trong danh mục. */
    public record AdminEnergyRemedyResponse(
            UUID id,
            String code,
            String title,
            String description,
            String rarity,
            String iconKey,
            UUID assetId,
            int energyGain,
            long pointsCost,
            int cooldownSeconds,
            boolean active,
            int sortOrder,
            Instant createdAt,
            Instant updatedAt,
            Long rowVersion) {
    }

    /** POST /admin/energy/remedies — tạo remedy mới. */
    public record CreateEnergyRemedyRequest(
            @NotBlank(message = "code is required")
            @Size(max = 64)
            String code,

            @NotBlank(message = "title is required")
            @Size(max = 160)
            String title,

            @NotBlank(message = "description is required")
            String description,

            @NotBlank(message = "rarity is required")
            @Size(max = 24)
            String rarity,

            @NotBlank(message = "iconKey is required")
            @Size(max = 80)
            String iconKey,

            UUID assetId,

            @NotNull(message = "energyGain is required")
            @Min(value = 1, message = "energyGain must be between 1 and 100")
            @Max(value = 100, message = "energyGain must be between 1 and 100")
            Integer energyGain,

            @NotNull(message = "pointsCost is required")
            @Min(value = 0, message = "pointsCost must be >= 0")
            Long pointsCost,

            @NotNull(message = "cooldownSeconds is required")
            @Min(value = 0, message = "cooldownSeconds must be >= 0")
            Integer cooldownSeconds,

            Boolean active,

            Integer sortOrder) {
    }

    /**
     * PUT /admin/energy/remedies/{id} — full replace (PUT semantics):
     * caller gửi đủ trường mutable; code KHÔNG đổi (khóa trace).
     */
    public record UpdateEnergyRemedyRequest(
            @NotBlank(message = "title is required")
            @Size(max = 160)
            String title,

            @NotBlank(message = "description is required")
            String description,

            @NotBlank(message = "rarity is required")
            @Size(max = 24)
            String rarity,

            @NotBlank(message = "iconKey is required")
            @Size(max = 80)
            String iconKey,

            UUID assetId,

            @NotNull(message = "energyGain is required")
            @Min(value = 1, message = "energyGain must be between 1 and 100")
            @Max(value = 100, message = "energyGain must be between 1 and 100")
            Integer energyGain,

            @NotNull(message = "pointsCost is required")
            @Min(value = 0, message = "pointsCost must be >= 0")
            Long pointsCost,

            @NotNull(message = "cooldownSeconds is required")
            @Min(value = 0, message = "cooldownSeconds must be >= 0")
            Integer cooldownSeconds,

            @NotNull(message = "active is required")
            Boolean active,

            @NotNull(message = "sortOrder is required")
            Integer sortOrder) {
    }

    /**
     * PATCH /admin/energy/remedies/{id} — partial update; chỉ trường
     * non-null được áp. Dùng cho toggle `active` nhanh trên UI.
     */
    public record PatchEnergyRemedyRequest(
            @Size(max = 160)
            String title,

            String description,

            @Size(max = 24)
            String rarity,

            @Size(max = 80)
            String iconKey,

            UUID assetId,

            @Min(value = 1, message = "energyGain must be between 1 and 100")
            @Max(value = 100, message = "energyGain must be between 1 and 100")
            Integer energyGain,

            @Min(value = 0, message = "pointsCost must be >= 0")
            Long pointsCost,

            @Min(value = 0, message = "cooldownSeconds must be >= 0")
            Integer cooldownSeconds,

            Boolean active,

            Integer sortOrder) {
    }
}
