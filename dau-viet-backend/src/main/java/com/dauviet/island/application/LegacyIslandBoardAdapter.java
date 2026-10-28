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
 * backfill. ISLAND-10-BE: thay lưới "1 slot = 1 tile GRASS" bằng một đảo
 * làng Việt 10x10 giàu cảnh quan — quảng trường sân đất, đường làng PATH,
 * vườn tre/lúa/sen trang trí, khu nền đá cao cấp:
 *
 * <ul>
 *   <li>Footprint cố định ~54 ô hình thoi liền mạch; slot được xếp vào các
 *       ô host theo vùng Tier (T1 quanh quảng trường, T2 vườn ngoài, T3 nền
 *       đá đỉnh/đáy). Slot thừa capacity vùng → quét ô GRASS trống theo
 *       thứ tự row-major (deterministic).</li>
 *   <li>Terrain phong phú: GRASS/DIRT/PATH/STONE + DECORATIVE kèm visualKey
 *       (bamboo_cluster, rice_patch, lotus_patch, heritage_lamp...).</li>
 *   <li>tileKey "tile_r{row}_c{col}" ổn định; mapping slotId → tileKey
 *       deterministic theo thứ tự slot_index — không đổi qua các lần đọc.</li>
 *   <li>Pure function — không ghi DB, không đổi pinned version, không đụng
 *       placements/UUID của user.</li>
 * </ul>
 */
@Component
public class LegacyIslandBoardAdapter {

    /** Lưới legacy cố định 10x10 — đảo hình thoi, không phải mọi ô có đất. */
    static final int GRID_ROWS = 10;
    static final int GRID_COLS = 10;

    /** Ô host mặc định cho slot Tier 1 — quanh quảng trường trung tâm. */
    private static final int[][] T1_HOSTS = {
            {4, 3}, {5, 6}, {3, 6}, {6, 3}};
    /** Ô host mặc định cho slot Tier 2 — vườn cây bốn góc mở rộng. */
    private static final int[][] T2_HOSTS = {
            {2, 2}, {2, 7}, {7, 2}, {7, 7}};
    /** Ô host mặc định cho slot Tier ≥3 — nền đá đỉnh và đáy đảo. */
    private static final int[][] T3_HOSTS = {
            {0, 4}, {0, 5}, {9, 4}, {9, 5}};

    /** Sân đất DIRT quảng trường trung tâm. */
    private static final int[][] DIRT_CELLS = {
            {4, 4}, {4, 5}, {5, 4}, {5, 5}};
    /** Đường làng PATH — trục dọc dẫn vào quảng trường hai đầu. */
    private static final int[][] PATH_CELLS = {
            {2, 4}, {2, 5}, {3, 4}, {3, 5},
            {6, 4}, {6, 5}, {7, 4}, {7, 5},
            {4, 2}, {5, 7}};
    /** Nền đá STONE vùng cao cấp (đỉnh/đáy đảo). */
    private static final int[][] STONE_CELLS = {
            {1, 4}, {1, 5}, {8, 4}, {8, 5}};

    /** Tile trang trí: coord → visualKey (FE tự render cảnh quan). */
    private static final Map<String, String> DECOR_VISUALS = Map.ofEntries(
            Map.entry("2:6", "bamboo_cluster"), Map.entry("7:3", "bamboo_cluster"),
            Map.entry("1:3", "bamboo_cluster"), Map.entry("8:6", "bamboo_cluster"),
            Map.entry("3:1", "lotus_patch"), Map.entry("6:7", "lotus_patch"),
            Map.entry("4:1", "rice_patch"), Map.entry("5:8", "rice_patch"),
            Map.entry("2:3", "shrub_cluster"), Map.entry("7:6", "shrub_cluster"),
            Map.entry("3:7", "grass_flowers"), Map.entry("6:2", "grass_flowers"),
            Map.entry("5:1", "banyan_sapling"), Map.entry("4:8", "banyan_sapling"),
            Map.entry("1:6", "stone_cluster"), Map.entry("8:3", "stone_cluster"),
            Map.entry("3:3", "heritage_lamp"), Map.entry("6:6", "heritage_lamp"),
            Map.entry("5:2", "clay_bricks"), Map.entry("4:7", "clay_bricks"));

    public record LegacyBoard(
            IslandResponse.BoardView board,
            List<IslandResponse.TileView> tiles,
            Map<UUID, String> tileKeyBySlotId,
            Map<String, List<String>> tileKeysByRegion) {
    }

    /**
     * Chiếu board + tiles làng Việt từ danh sách slot của version legacy.
     *
     * @param unlockedTier tier hiện tại của đảo (để set cờ unlocked trên tile)
     */
    public LegacyBoard project(UUID layoutVersionId, int versionNumber,
                               String themeKey, int unlockedTier,
                               List<IslandSlot> slots,
                               List<IslandLayoutRegion> regions) {
        IslandResponse.BoardView board = new IslandResponse.BoardView(
                layoutVersionId, versionNumber,
                GRID_ROWS, GRID_COLS,
                128.0, 64.0, 0.0, 0.0, "ISOMETRIC", themeKey);

        // Region lookup: code → tier, và tier → regionCode đầu tiên (giữ
        // membership region cho tile cảnh quan khớp vùng unlock).
        Map<String, Integer> regionTierByCode = new LinkedHashMap<>();
        Map<Integer, String> regionCodeByTier = new LinkedHashMap<>();
        for (IslandLayoutRegion r : regions) {
            regionTierByCode.put(r.getRegionCode(), r.getUnlockTier());
            regionCodeByTier.putIfAbsent(r.getUnlockTier(), r.getRegionCode());
        }

        // Footprint đảo hình thoi 10x10 (hàng ngoài hẹp, giữa rộng).
        List<int[]> footprint = footprintCells();

        // Gán slot → ô host theo vùng tier (1=trung tâm, 2=vườn, ≥3=nền đá).
        // Thứ tự slot_index ổn định → mapping ổn định mọi lần đọc.
        List<IslandSlot> ordered = new ArrayList<>(slots);
        ordered.sort(java.util.Comparator.comparingInt(IslandSlot::getSlotIndex));
        Map<String, IslandSlot> slotByCoord = new LinkedHashMap<>();
        Map<Integer, Integer> nextHostByZone = new LinkedHashMap<>();
        java.util.Set<String> usedCoords = new java.util.HashSet<>();
        for (IslandSlot s : ordered) {
            int zone = zoneOf(effectiveTier(s, regionTierByCode));
            int[] coord = nextHostCoord(zone, nextHostByZone, usedCoords,
                    footprint);
            slotByCoord.put(coord[0] + ":" + coord[1], s);
            usedCoords.add(coord[0] + ":" + coord[1]);
        }

        Map<UUID, String> tileKeyBySlotId = new LinkedHashMap<>();
        Map<String, List<String>> tileKeysByRegion = new LinkedHashMap<>();

        List<IslandResponse.TileView> tiles = new ArrayList<>(footprint.size());
        for (int[] cell : footprint) {
            int r = cell[0], c = cell[1];
            String coord = r + ":" + c;
            String tileKey = "tile_r" + r + "_c" + c;
            IslandSlot host = slotByCoord.get(coord);

            // Vùng của ô: slot host kế thừa tier/region của slot; ô cảnh quan
            // theo zone địa lý (đỉnh/đáy = T3, lõi = T1, còn lại = T2).
            int zone = host != null
                    ? zoneOf(effectiveTier(host, regionTierByCode))
                    : zoneOfCoord(r, c);
            String regionCode = host != null && host.getRegionCode() != null
                    ? host.getRegionCode()
                    : regionCodeByTier.get(zone);
            int effTier = host != null
                    ? effectiveTier(host, regionTierByCode)
                    : zone;

            String terrain;
            String visualKey = null;
            if (host != null) {
                // Host giữ terrain của ô (STONE cho nền đá T3) — buildable.
                terrain = terrainOfCoord(coord);
                if ("DECORATIVE".equals(terrain)) terrain = "GRASS";
            } else {
                terrain = terrainOfCoord(coord);
                visualKey = DECOR_VISUALS.get(coord);
            }

            // Vùng cao cấp nâng elevation nhẹ tạo chiều sâu thị giác.
            int elevation = zone >= 3 ? 1 : 0;

            tiles.add(new IslandResponse.TileView(
                    tileKey, r, c, terrain, regionCode,
                    effTier, effTier <= unlockedTier,
                    host != null, visualKey, elevation));

            if (host != null) {
                tileKeyBySlotId.put(host.getId(), tileKey);
            }
            if (regionCode != null) {
                tileKeysByRegion.computeIfAbsent(regionCode,
                        k -> new ArrayList<>()).add(tileKey);
            }
        }

        return new LegacyBoard(board, tiles, tileKeyBySlotId, tileKeysByRegion);
    }

    /** Footprint hình thoi: số cột mỗi hàng [2,4,6,8,8,8,6,6,4,2] căn giữa. */
    private static List<int[]> footprintCells() {
        int[][] rows = {
                {4, 5},
                {3, 4, 5, 6},
                {2, 3, 4, 5, 6, 7},
                {1, 2, 3, 4, 5, 6, 7, 8},
                {1, 2, 3, 4, 5, 6, 7, 8},
                {1, 2, 3, 4, 5, 6, 7, 8},
                {2, 3, 4, 5, 6, 7},
                {2, 3, 4, 5, 6, 7},
                {3, 4, 5, 6},
                {4, 5},
        };
        List<int[]> cells = new ArrayList<>(54);
        for (int r = 0; r < rows.length; r++) {
            for (int c : rows[r]) cells.add(new int[]{r, c});
        }
        return cells;
    }

    /** Tier hiệu lực của slot: region.unlockTier nếu có, else tierRequired. */
    private static int effectiveTier(IslandSlot s,
                                     Map<String, Integer> regionTierByCode) {
        Integer regionTier = s.getRegionCode() != null
                ? regionTierByCode.get(s.getRegionCode()) : null;
        return regionTier != null ? regionTier : s.getTierRequired();
    }

    /** Vùng host: tier 1 → 1, tier 2 → 2, tier ≥3 → 3. */
    private static int zoneOf(int tier) {
        return tier <= 1 ? 1 : Math.min(tier, 3);
    }

    /** Vùng địa lý của ô cảnh quan: đỉnh/đáy = T3, lõi 3..6 = T1, còn lại T2. */
    private static int zoneOfCoord(int r, int c) {
        if (r <= 1 || r >= 8) return 3;
        if (r >= 3 && r <= 6 && c >= 3 && c <= 6) return 1;
        return 2;
    }

    /** Terrain nền của một coord (trước khi xét host/buildable). */
    private static String terrainOfCoord(String coord) {
        if (DECOR_VISUALS.containsKey(coord)) return "DECORATIVE";
        for (int[] cell : DIRT_CELLS) {
            if ((cell[0] + ":" + cell[1]).equals(coord)) return "DIRT";
        }
        for (int[] cell : PATH_CELLS) {
            if ((cell[0] + ":" + cell[1]).equals(coord)) return "PATH";
        }
        for (int[] cell : STONE_CELLS) {
            if ((cell[0] + ":" + cell[1]).equals(coord)) return "STONE";
        }
        return "GRASS";
    }

    /**
     * Ô host tiếp theo cho một vùng tier: ưu tiên danh sách host định sẵn;
     * hết capacity → quét footprint chọn ô GRASS trống đầu tiên (row-major),
     * deterministic và không bao giờ trùng ô đã gán.
     */
    private static int[] nextHostCoord(int zone,
                                       Map<Integer, Integer> nextHostByZone,
                                       java.util.Set<String> usedCoords,
                                       List<int[]> footprint) {
        int[][] hostList = zone == 1 ? T1_HOSTS : zone == 2 ? T2_HOSTS : T3_HOSTS;
        int idx = nextHostByZone.getOrDefault(zone, 0);
        while (idx < hostList.length
                && usedCoords.contains(hostList[idx][0] + ":" + hostList[idx][1])) {
            idx++;
        }
        if (idx < hostList.length) {
            nextHostByZone.put(zone, idx + 1);
            return hostList[idx];
        }
        // Overflow: ô GRASS trống đầu tiên cùng vùng → rồi bất kỳ vùng nào.
        for (int pass = 0; pass < 2; pass++) {
            for (int[] cell : footprint) {
                String coord = cell[0] + ":" + cell[1];
                if (usedCoords.contains(coord)) continue;
                if (!"GRASS".equals(terrainOfCoord(coord))) continue;
                if (pass == 0 && zoneOfCoord(cell[0], cell[1]) != zone) continue;
                return cell;
            }
        }
        // Không còn ô trống — trả ô đầu footprint (đường cùng, vẫn deterministic).
        return footprint.get(0);
    }
}
