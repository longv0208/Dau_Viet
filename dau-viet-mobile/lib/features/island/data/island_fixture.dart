import 'island_dto.dart';

/// Fixture nội bộ dành riêng cho việc phát triển và xem trước Isometric Renderer.
/// Độc lập hoàn toàn với ApiIslandRepository và production data provider,
/// tuân thủ nguyên tắc không tự động fallback khi API sản xuất gặp lỗi.
///
/// V65: sinh lưới đồng tâm 10x10 (T1 6x6 / T2 8x8 / T3 10x10) với địa hình
/// đảo nhiệt đới giống backend — vành cát bờ biển, vách đá & đồi cỏ Bắc,
/// quảng trường + đường gạch trung tâm. MỌI ô đều có slot buildable để demo
/// cơ chế "chia đảo thành nhiều ô, đặt vào ô nào cũng được".
class IslandFixture {
  IslandFixture._();

  /// Vật phẩm mẫu đặt sẵn trên đảo demo (slotId -> placement + anchor tile).
  static const Map<String, _FixturePlacement> _presetPlacements = {
    'slot_13': _FixturePlacement( // tile_2_2 — TIER_1
      itemId: 'item_dinh_lang',
      code: 'dinh_lang',
      name: 'Đình Làng Mái Đao',
      renderKey: 'dinh_lang',
    ),
    'slot_23': _FixturePlacement( // tile_3_2
      itemId: 'item_decor_nha_tranh',
      code: 'decor_nha_tranh',
      name: 'Nhà Tranh Vách Đất',
      renderKey: 'decor_nha_tranh',
    ),
    'slot_25': _FixturePlacement( // tile_2_4
      itemId: 'item_decor_cau_kieu',
      code: 'decor_cau_kieu',
      name: 'Cầu Kiều Mái Cong',
      renderKey: 'decor_cau_kieu',
    ),
    'slot_46': _FixturePlacement( // tile_4_5
      itemId: 'item_decor_ho_sen',
      code: 'decor_ho_sen',
      name: 'Thủy Tạ Hồ Sen',
      renderKey: 'decor_ho_sen',
    ),
    'slot_55': _FixturePlacement( // tile_5_4
      itemId: 'item_decor_gieng_co',
      code: 'decor_gieng_co',
      name: 'Giếng Cổ Đá Xanh',
      renderKey: 'decor_gieng_co',
    ),
    'slot_36': _FixturePlacement( // tile_3_5
      itemId: 'item_decor_cot_co',
      code: 'decor_cot_co',
      name: 'Cột cờ truyền thống',
      renderKey: 'decor_cot_co',
    ),
    'slot_63': _FixturePlacement( // tile_6_2 — TIER_2
      itemId: 'item_decor_cay_da',
      code: 'decor_cay_da',
      name: 'Cây Đa Cổ Thụ',
      renderKey: 'decor_cay_da',
      tier: 2,
    ),
    'slot_14': _FixturePlacement( // tile_1_3 — TIER_2
      itemId: 'item_cong_lang',
      code: 'cong_lang',
      name: 'Cổng Làng Cổ Kính',
      renderKey: 'cong_lang',
      tier: 2,
    ),
    'slot_77': _FixturePlacement( // tile_7_6 — TIER_3
      itemId: 'item_khue_van',
      code: 'khue_van',
      name: 'Khuê Văn Các',
      renderKey: 'khue_van',
      tier: 3,
    ),
  };

  static IslandDto createHeritageVillageFixture({int tier = 1}) {
    const rows = 10;
    const cols = 10;

    final slots = <IslandSlotDto>[];
    final tiles = <IslandTileDto>[];

    int slotIndex = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        slotIndex++;
        final int tileTier;
        final String regionCode;
        if (r >= 2 && r <= 7 && c >= 2 && c <= 7) {
          tileTier = 1;
          regionCode = 'TIER_1';
        } else if (r >= 1 && r <= 8 && c >= 1 && c <= 8) {
          tileTier = 2;
          regionCode = 'TIER_2';
        } else {
          tileTier = 3;
          regionCode = 'TIER_3';
        }

        // Địa hình đảo nhiệt đới — đồng bộ với migration V65
        IslandTerrainType terrain = IslandTerrainType.grass;
        int elevation = 0;
        String? decorKey;
        bool buildable = true;

        // Vành cát bờ biển (hàng ngoài Nam + hai mép Đông/Tây)
        if (r == 9 || c == 9 || c == 0 || (r == 8 && c >= 2 && c <= 8)) {
          terrain = IslandTerrainType.sand;
        }
        // Vách đá & đồi cỏ phía Bắc
        if (r == 0) {
          terrain = IslandTerrainType.stone;
          decorKey = 'rock';
          elevation = 1;
          buildable = false;
        } else if (r == 1 && c >= 1 && c <= 8) {
          terrain = IslandTerrainType.grass;
          elevation = 1;
        }
        // Cọ nhiệt đới trên đồi cỏ Bắc — cảnh quan cố định
        if ((r == 1 && (c == 2 || c == 5 || c == 7)) || (r == 2 && c == 8)) {
          terrain = IslandTerrainType.grass;
          decorKey = 'palm';
          elevation = 1;
          buildable = false;
        }
        // Thác + hồ ở sườn Tây Bắc
        if ((r == 1 && c == 1) || (r == 2 && c == 1)) {
          terrain = IslandTerrainType.stone;
          decorKey = 'waterfall';
          elevation = 1;
          buildable = false;
        }
        if (r == 3 && c == 1) {
          terrain = IslandTerrainType.water;
          decorKey = 'pool';
          buildable = false;
        }
        // Cầu tàu gỗ + thuyền ở bờ Tây Nam & Đông Nam
        if (r == 8 && c == 1) {
          terrain = IslandTerrainType.sand;
          decorKey = 'dock';
          buildable = false;
        }
        if ((r == 9 && c == 1) || (r == 9 && c == 7)) {
          terrain = IslandTerrainType.water;
          decorKey = 'boat';
          buildable = false;
        }
        if (r == 8 && c == 8) {
          terrain = IslandTerrainType.sand;
          decorKey = 'dock';
          buildable = false;
        }
        // Đá phụ / hòn nhỏ trên vành nước ngoài cùng
        if ((c == 0 && (r == 2 || r == 5 || r == 7)) ||
            (r == 9 && (c == 3 || c == 6)) ||
            (c == 9 && (r == 3 || r == 6))) {
          terrain = IslandTerrainType.water;
          decorKey = 'islet';
          buildable = false;
        }
        // Quảng trường + đường gạch trung tâm
        if (r >= 3 && r <= 4 && c >= 3 && c <= 4) {
          terrain = IslandTerrainType.dirt;
          elevation = 1;
          decorKey = null;
          buildable = true;
        } else if ((r == 5 && c >= 2 && c <= 7) ||
            (c == 5 && r >= 2 && r <= 7)) {
          terrain = IslandTerrainType.path;
          decorKey = null;
          buildable = true;
        }
        // Thảm hoa dại ven đường trong TIER_1
        if (terrain == IslandTerrainType.grass &&
            tileTier == 1 &&
            decorKey == null &&
            ((r == 3 && (c == 2 || c == 6)) ||
                (r == 6 && c == 6) ||
                (r == 4 && c == 7))) {
          decorKey = 'flowers';
        }

        // Chỉ ô buildable mới host slot đặt vật phẩm — ô cảnh quan cố định
        // (thác/hồ/cầu tàu/thuyền/đá phụ/đá/cọ) không có slot trên đảo.
        final bool slotOnTile = buildable;
        final slotId = 'slot_$slotIndex';
        final preset = _presetPlacements[slotId];
        final bool slotUnlocked = tier >= tileTier;
        final placement = (preset != null && tier >= preset.tier)
            ? IslandPlacementDto(
                itemId: preset.itemId,
                code: preset.code,
                name: preset.name,
                renderKey: preset.renderKey,
              )
            : null;

        if (slotOnTile) {
          slots.add(
            IslandSlotDto(
              slotId: slotId,
              stableSlotKey: slotId,
              x: 0.06 + (c / (cols - 1)) * 0.88,
              y: 0.06 + (r / (rows - 1)) * 0.88,
              zIndex: slotIndex * 10,
              unlockTier: tileTier,
              unlocked: slotUnlocked,
              regionCode: regionCode,
              allowedCategories: const [
                'DECOR',
                'MO_HINH',
                'HISTORICAL_REPLICA',
                'DIGITAL_EDITION',
              ],
              tileRow: r,
              tileCol: c,
              tileKey: 'tile_${r}_$c',
              placement: placement,
            ),
          );
        }

        tiles.add(
          IslandTileDto(
            key: 'tile_${r}_$c',
            row: r,
            col: c,
            terrainType: terrain,
            regionCode: regionCode,
            unlockTier: tileTier,
            elevation: elevation.toDouble(),
            decorKey: decorKey,
            slotId: slotOnTile ? slotId : null,
            buildable: buildable,
            unlocked: slotUnlocked,
          ),
        );
      }
    }

    final regions = <IslandLayoutRegionDto>[
      const IslandLayoutRegionDto(
        regionCode: 'TIER_1',
        unlockTier: 1,
        unlocked: true,
        label: 'Đảo Nhỏ',
        boundsJson: '{"x":0.20,"y":0.20,"width":0.60,"height":0.60}',
      ),
      IslandLayoutRegionDto(
        regionCode: 'TIER_2',
        unlockTier: 2,
        unlocked: tier >= 2,
        label: 'Đảo Vừa',
        boundsJson: '{"x":0.10,"y":0.10,"width":0.80,"height":0.80}',
      ),
      IslandLayoutRegionDto(
        regionCode: 'TIER_3',
        unlockTier: 3,
        unlocked: tier >= 3,
        label: 'Đảo Lớn',
        boundsJson: '{"x":0.0,"y":0.0,"width":1.0,"height":1.0}',
      ),
    ];

    final board = IslandBoardDto(
      rows: rows,
      cols: cols,
      tileWidth: 84.0,
      tileHeight: 42.0,
      tiles: tiles,
      fromBackend: true,
    );

    return IslandDto(
      tier: tier,
      maxTier: 3,
      rowVersion: 1,
      currentExp: tier == 1 ? 450 : (tier == 2 ? 1800 : 3500),
      currentLevel: tier == 1 ? 5 : (tier == 2 ? 8 : 10),
      nextTierRequiredLevel: tier == 1 ? 5 : (tier == 2 ? 10 : null),
      nextTierRequiredExp: tier == 1 ? 500 : (tier == 2 ? 2000 : null),
      nextTierSlotCount: tier == 1 ? 64 : (tier == 2 ? 100 : 0),
      canUpgrade: tier < 3,
      eventsCompleted: tier == 1 ? 15 : (tier == 2 ? 30 : 30),
      layoutCode: 'heritage-village',
      layoutVersionId: '22200000-2222-4000-8000-000000000004',
      layoutVersionNumber: 4,
      canvasWidth: 960.0,
      canvasHeight: 720.0,
      themeKey: 'heritage_vietnam',
      regions: regions,
      slots: slots,
      board: board,
      tiers: [
        const IslandTierInfoDto(
          tier: 1,
          nameKey: 'tier.small',
          stageLabel: 'Đảo Nhỏ',
          slotCount: 36,
          requiredCompletedEvents: 0,
          requiredLevel: 1,
          unlocked: true,
        ),
        IslandTierInfoDto(
          tier: 2,
          nameKey: 'tier.medium',
          stageLabel: 'Đảo Vừa',
          slotCount: 64,
          requiredCompletedEvents: 0,
          requiredLevel: 2,
          unlocked: tier >= 2,
        ),
        IslandTierInfoDto(
          tier: 3,
          nameKey: 'tier.grand',
          stageLabel: 'Đảo Lớn',
          slotCount: 100,
          requiredCompletedEvents: 0,
          requiredLevel: 3,
          unlocked: tier >= 3,
        ),
      ],
    );
  }
}

class _FixturePlacement {
  final String itemId;
  final String code;
  final String name;
  final String renderKey;
  final int tier;

  const _FixturePlacement({
    required this.itemId,
    required this.code,
    required this.name,
    required this.renderKey,
    this.tier = 1,
  });
}
