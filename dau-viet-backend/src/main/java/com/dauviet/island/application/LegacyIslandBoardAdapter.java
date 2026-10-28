package com.dauviet.island.application;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.dauviet.island.api.dto.IslandResponse;
import com.dauviet.island.domain.IslandLayoutRegion;
import com.dauviet.island.domain.IslandSlot;

/**
 * Chiếu board/tiles deterministic cho layout version rect-model legacy
 * (V44 trở về trước — không có island_layout_boards / island_tiles).
 *
 * <p>ISLAND-09-BE: layout v1 đã PUBLISHED/ARCHIVED là immutable — không
 * backfill. Adapter sinh cấu trúc tile tương thích lúc đọc /me/island:
 *
 * <ul>
 *   <li>Mỗi slot → đúng một tile (một tile tối đa một slot — khớp rule
 *       ux_island_slot_tile của model mới).</li>
 *   <li>Lưới cố định 4 cột: slot_index i → row=(i-1)/4, col=(i-1)%4 —
 *       deterministic, ổn định qua mọi lần đọc, không phụ thuộc pixel.</li>
 *   <li>tileKey "tile_r{row}_c{col}"; regionCode/tier lấy theo slot để
 *       membership region và trạng thái khóa nhất quán với slots hiện có.</li>
 *   <li>Pure function — không ghi DB, không đổi pinned version của user.</li>
 * </ul>
 */
@Component
public class LegacyIslandBoardAdapter {

    /** Lưới legacy: 4 cột, số hàng suy ra từ số slot (12 slot → 3 hàng). */
    static final int LEGACY_GRID_COLUMNS = 4;

    public record LegacyBoard(
            IslandResponse.BoardView board,
            List<IslandResponse.TileView> tiles,
            Map<UUID, String> tileKeyBySlotId,
            Map<String, List<String>> tileKeysByRegion) {
    }

    /**
     * Chiếu board + tiles từ danh sách slot của version legacy.
     *
     * @param unlockedTier tier hiện tại của đảo (để set cờ unlocked trên tile)
     */
    public LegacyBoard project(UUID layoutVersionId, int versionNumber,
                               String themeKey, int unlockedTier,
                               List<IslandSlot> slots,
                               List<IslandLayoutRegion> regions) {
        int slotCount = slots.size();
        int gridRows = Math.max(1, (int) Math.ceil(
                (double) slotCount / LEGACY_GRID_COLUMNS));
        int gridCols = slotCount == 0 ? 1
                : Math.min(LEGACY_GRID_COLUMNS, slotCount);

        IslandResponse.BoardView board = new IslandResponse.BoardView(
                layoutVersionId, versionNumber,
                gridRows, Math.max(LEGACY_GRID_COLUMNS, gridCols),
                128.0, 64.0, 0.0, 0.0, "ISOMETRIC", themeKey);

        Map<String, Integer> regionTierByCode = new LinkedHashMap<>();
        for (IslandLayoutRegion r : regions) {
            regionTierByCode.put(r.getRegionCode(), r.getUnlockTier());
        }

        List<IslandResponse.TileView> tiles = new ArrayList<>(slotCount);
        Map<UUID, String> tileKeyBySlotId = new LinkedHashMap<>();
        Map<String, List<String>> tileKeysByRegion = new LinkedHashMap<>();

        for (IslandSlot s : slots) {
            int idx = Math.max(1, s.getSlotIndex());
            int row = (idx - 1) / LEGACY_GRID_COLUMNS;
            int col = (idx - 1) % LEGACY_GRID_COLUMNS;
            String tileKey = "tile_r" + row + "_c" + col;

            Integer regionTier = s.getRegionCode() != null
                    ? regionTierByCode.get(s.getRegionCode()) : null;
            int effectiveTier = regionTier != null
                    ? regionTier : s.getTierRequired();

            tiles.add(new IslandResponse.TileView(
                    tileKey, row, col, "GRASS", s.getRegionCode(),
                    effectiveTier, effectiveTier <= unlockedTier,
                    true, null, 0));

            tileKeyBySlotId.put(s.getId(), tileKey);
            if (s.getRegionCode() != null) {
                tileKeysByRegion.computeIfAbsent(s.getRegionCode(),
                        k -> new ArrayList<>()).add(tileKey);
            }
        }

        return new LegacyBoard(board, tiles, tileKeyBySlotId, tileKeysByRegion);
    }
}
