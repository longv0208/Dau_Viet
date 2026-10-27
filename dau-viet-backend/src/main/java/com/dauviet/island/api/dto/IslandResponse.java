package com.dauviet.island.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * GET /api/v1/me/island — trạng thái đảo + slot map đầy đủ để client render.
 *
 * <p>ISLAND-01: thêm currentExp, currentLevel, nextTierRequiredLevel,
 * nextTierRequiredExp — eligibility dựa theo Level tài khoản.
 *
 * <p>ISLAND-02: thêm maxTier suy ra từ active island policies để Flutter
 * không cần hard-code Tier 3 là max.
 *
 * <p>ISLAND-03/04: thêm layout metadata (layoutCode, layoutVersionId, canvasWidth,
 * canvasHeight, themeKey, regions, sceneLayers) và slot widthNorm/heightNorm/allowedCategories
 * để Flutter render data-driven.
 */
public record IslandResponse(
        int tier,
        int maxTier,
        long rowVersion,
        long eventsCompleted,
        Integer nextTier,
        int nextTierRequiredEvents,
        int nextTierSlotCount,
        boolean canUpgrade,
        Instant upgradedAt,
        List<SlotView> slots,
        Instant serverTime,
        long currentExp,
        int currentLevel,
        Integer nextTierRequiredLevel,
        Long nextTierRequiredExp,
        // Layout metadata (ISLAND-03/04)
        String layoutCode,
        UUID layoutVersionId,
        int layoutVersionNumber,
        double canvasWidth,
        double canvasHeight,
        String themeKey,
        List<RegionView> regions,
        List<SceneLayerView> sceneLayers
) {
    /** Một ô đất: locked/unlocked + item đang đặt (null = trống). */
    public record SlotView(
            UUID slotId,
            int slotIndex,
            int tierRequired,
            boolean unlocked,
            double coordX,
            double coordY,
            UUID placedItemId,
            String placedItemCode,
            String placedRenderKey,
            Instant placedAt,
            // V44 layout fields
            String stableSlotKey,
            String regionCode,
            int zIndex,
            double anchorX,
            double anchorY,
            double widthNorm,
            double heightNorm,
            List<String> allowedCategories
    ) {
    }

    /** Vùng đất: metadata để Flutter vẽ overlay khoá/mở (ISLAND-03/04). */
    public record RegionView(
            String regionCode,
            int unlockTier,
            boolean unlocked,
            String label,
            String boundsJson
    ) {
    }

    /** Scene layer: Flutter render theo render_order ASC (ISLAND-03/04). */
    public record SceneLayerView(
            String layerKey,
            String layerType,
            int renderOrder,
            String assetRef,
            String visibilityRuleJson
    ) {
    }
}
