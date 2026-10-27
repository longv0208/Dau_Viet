package com.dauviet.island.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.dauviet.island.domain.IslandExceptions;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

/**
 * DTOs cho Admin Island Builder (ISLAND-04).
 */
public final class AdminIslandLayoutDtos {

    private AdminIslandLayoutDtos() {}

    public record LayoutSummaryResponse(
            UUID id,
            String layoutKey,
            String name,
            String description,
            double canvasWidth,
            double canvasHeight,
            String themeKey,
            boolean defaultLayout,
            int versionCount,
            Integer publishedVersionNumber,
            UUID publishedVersionId,
            Integer latestDraftVersionNumber,
            UUID latestDraftVersionId,
            String latestStatus,
            Instant updatedAt
    ) {}

    public record VersionSummaryResponse(
            UUID id,
            UUID definitionId,
            int versionNumber,
            String status,
            long rowVersion,
            Instant publishedAt,
            Instant archivedAt,
            Instant createdAt,
            Instant updatedAt
    ) {}

    public record LayoutDetailResponse(
            UUID id,
            String layoutKey,
            String name,
            String description,
            double canvasWidth,
            double canvasHeight,
            String themeKey,
            boolean defaultLayout,
            Instant createdAt,
            Instant updatedAt,
            List<VersionSummaryResponse> versions
    ) {}

    public record VersionDetailResponse(
            UUID id,
            UUID definitionId,
            String layoutKey,
            String layoutName,
            double canvasWidth,
            double canvasHeight,
            String themeKey,
            boolean defaultLayout,
            int versionNumber,
            String status,
            long rowVersion,
            Instant publishedAt,
            Instant archivedAt,
            Instant createdAt,
            Instant updatedAt,
            List<RegionDto> regions,
            List<SlotDto> slots,
            List<SceneLayerDto> sceneLayers,
            List<TierPolicySummary> tierPolicies
    ) {}

    public record TierPolicySummary(
            int tier,
            int slotCount,
            Integer requiredLevel
    ) {}

    public record RegionDto(
            UUID id,
            @NotBlank String regionCode,
            int unlockTier,
            String label,
            String boundsJson,
            int sortOrder
    ) {}

    public record SlotDto(
            UUID id,
            int slotIndex,
            @NotBlank String stableSlotKey,
            int tierRequired,
            String regionCode,
            double coordX,
            double coordY,
            int zIndex,
            double anchorX,
            double anchorY,
            double widthNorm,
            double heightNorm,
            List<String> allowedCategories
    ) {}

    public record SceneLayerDto(
            UUID id,
            @NotBlank String layerKey,
            @NotBlank String layerType,
            int renderOrder,
            String assetRef,
            String visibilityRuleJson
    ) {}

    public record CreateLayoutRequest(
            @NotBlank String layoutKey,
            @NotBlank String name,
            String description,
            @Positive Double canvasWidth,
            @Positive Double canvasHeight,
            String themeKey,
            Boolean defaultLayout
    ) {}

    public record UpdateLayoutRequest(
            String name,
            String description,
            @Positive Double canvasWidth,
            @Positive Double canvasHeight,
            String themeKey,
            Boolean defaultLayout
    ) {}

    public record UpdateDraftSnapshotRequest(
            @NotNull @PositiveOrZero Long expectedRevision,
            @Valid List<RegionDto> regions,
            @Valid List<SlotDto> slots,
            @Valid List<SceneLayerDto> sceneLayers
    ) {}

    public record RevisionRequest(
            @NotNull @PositiveOrZero Long expectedRevision
    ) {}

    public record ValidationReportResponse(
            boolean valid,
            List<IslandExceptions.IslandLayoutValidationException.ValidationError> errors
    ) {}
}
