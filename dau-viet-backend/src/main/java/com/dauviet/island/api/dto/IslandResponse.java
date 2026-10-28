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
        List<SceneLayerView> sceneLayers,
        // Tile board (ISLAND-09-BE) — additive; board/tiles từ island_layout_boards
        // + island_tiles, hoặc LegacyIslandBoardAdapter cho layout rect-model cũ
        BoardView board,
        List<TileView> tiles
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
            String placedItemName,
            String placedRenderKey,
            UUID placedAssetId,
            Instant placedAt,
            // V44 layout fields
            String stableSlotKey,
            String regionCode,
            int zIndex,
            double anchorX,
            double anchorY,
            double widthNorm,
            double heightNorm,
            List<String> allowedCategories,
            // V48: key của tile host (null = slot legacy chưa link)
            String tileKey
    ) {
        public SlotView(
                UUID slotId,
                int slotIndex,
                int tierRequired,
                boolean unlocked,
                double coordX,
                double coordY,
                UUID placedItemId,
                String placedItemCode,
                String placedItemName,
                String placedRenderKey,
                Instant placedAt,
                String stableSlotKey,
                String regionCode,
                int zIndex,
                double anchorX,
                double anchorY,
                double widthNorm,
                double heightNorm,
                List<String> allowedCategories
        ) {
            this(
                    slotId, slotIndex, tierRequired, unlocked, coordX, coordY,
                    placedItemId, placedItemCode, placedItemName, placedRenderKey, null, placedAt,
                    stableSlotKey, regionCode, zIndex, anchorX, anchorY,
                    widthNorm, heightNorm, allowedCategories, null
            );
        }

        public SlotView(
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
                String stableSlotKey,
                String regionCode,
                int zIndex,
                double anchorX,
                double anchorY,
                double widthNorm,
                double heightNorm,
                List<String> allowedCategories
        ) {
            this(
                    slotId, slotIndex, tierRequired, unlocked, coordX, coordY,
                    placedItemId, placedItemCode, placedItemCode, placedRenderKey, null, placedAt,
                    stableSlotKey, regionCode, zIndex, anchorX, anchorY,
                    widthNorm, heightNorm, allowedCategories, null
            );
        }
    }

    /**
     * Cấu hình lưới board isometric (V48 ISLAND-09-BE). tileWidth/tileHeight
     * là kích thước ô hình thoi theo quy ước FE chiếu:
     * screenX = (column - row) * tileWidth / 2 + boardOriginX
     * screenY = (column + row) * tileHeight / 2 + boardOriginY
     */
    public record BoardView(
            UUID layoutVersionId,
            int versionNumber,
            int gridRows,
            int gridColumns,
            double tileWidth,
            double tileHeight,
            double boardOriginX,
            double boardOriginY,
            String projectionType,
            String themeKey
    ) {
    }

    /**
     * Ô địa hình trên lưới (V48). row/column là tọa độ logic — JSON giữ tên
     * `row`/`column` theo contract FE; `unlocked` suy từ effective tier
     * (region.unlockTier nếu có region, ngược lại unlock_tier của tile).
     */
    public record TileView(
            String tileKey,
            int row,
            int column,
            String terrainType,
            String regionCode,
            int unlockTier,
            boolean unlocked,
            boolean buildable,
            String visualKey,
            int elevation
    ) {
    }

    /** Vùng đất: metadata để Flutter vẽ overlay khoá/mở (ISLAND-03/04).
     *  tileKeys (V48): membership = các tile thuộc region này. */
    public record RegionView(
            String regionCode,
            int unlockTier,
            boolean unlocked,
            String label,
            String boundsJson,
            List<String> tileKeys
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
