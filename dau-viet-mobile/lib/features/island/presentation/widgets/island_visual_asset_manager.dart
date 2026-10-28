import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../data/island_dto.dart';

/// Đặc tả hiển thị một sprite tiểu cảnh 2.5D trên ô tile isometric.
@immutable
class IslandScenerySpriteSpec {
  final String assetPath;
  final double widthFactor;
  final double heightFactor;
  final double bottomPadFactor;
  final double shadowWidthFactor;
  final double shadowHeightFactor;
  final double shadowOpacity;

  const IslandScenerySpriteSpec({
    required this.assetPath,
    this.widthFactor = 1.0,
    this.heightFactor = 1.8,
    this.bottomPadFactor = 0.10,
    this.shadowWidthFactor = 0.56,
    this.shadowHeightFactor = 0.34,
    this.shadowOpacity = 0.24,
  });
}

/// Quản lý tập trung toàn bộ Visual Assets (PNG 2.5D Sprites) của Đảo Di Sản.
/// Tra cứu theo:
/// - terrainType -> Isometric 2:1 ground tile sprites (`assets/island/terrain/*.png`)
/// - visualKey / decorKey -> Isolated 2.5D Vietnamese scenery sprites (`assets/island/scenery/*.png`)
/// - renderKey / code / assetId -> Heritage architectural building sprites (`assets/items/*.png` & `assets/island/buildings/*.png`)
class IslandVisualAssetManager {
  IslandVisualAssetManager._();

  static const String grassTile01 = 'assets/island/terrain/tile_grass_01.png';
  static const String grassTile02 = 'assets/island/terrain/tile_grass_02.png';
  static const String grassTile03 = 'assets/island/terrain/tile_grass_03.png';
  static const String dirtCourtyardTile = 'assets/island/terrain/tile_dirt_courtyard.png';
  static const String villagePathTile = 'assets/island/terrain/tile_village_path.png';
  static const String stoneTerraceTile = 'assets/island/terrain/tile_stone_terrace.png';

  static const String buildableParcelPlinth = 'assets/island/scenery/buildable_parcel_plinth.png';
  static const String bambooGroveLarge = 'assets/island/scenery/bamboo_grove_large.png';
  static const String bambooGroveSmall = 'assets/island/scenery/bamboo_grove_small.png';
  static const String banyanSapling = 'assets/island/scenery/banyan_sapling.png';
  static const String floweringShrub = 'assets/island/scenery/flowering_shrub.png';
  static const String wildflowersPatch = 'assets/island/scenery/wildflowers_patch.png';
  static const String ricePaddyPatch = 'assets/island/scenery/rice_paddy_patch.png';
  static const String lotusPondCluster = 'assets/island/scenery/lotus_pond_cluster.png';
  static const String stoneLantern = 'assets/island/scenery/stone_lantern.png';
  static const String ancientStoneWell = 'assets/island/scenery/ancient_stone_well.png';
  static const String mossyRockCluster = 'assets/island/scenery/mossy_rock_cluster.png';
  static const String terracottaJarsFence = 'assets/island/scenery/terracotta_jars_fence.png';

  static const List<String> allCoreSprites = [
    grassTile01,
    grassTile02,
    grassTile03,
    dirtCourtyardTile,
    villagePathTile,
    stoneTerraceTile,
    buildableParcelPlinth,
    bambooGroveLarge,
    bambooGroveSmall,
    banyanSapling,
    floweringShrub,
    wildflowersPatch,
    ricePaddyPatch,
    lotusPondCluster,
    stoneLantern,
    ancientStoneWell,
    mossyRockCluster,
    terracottaJarsFence,
  ];

  static bool _precached = false;

  /// Precache toàn bộ sprite cốt lõi vào bộ nhớ đệm hình ảnh để cuộn/zoom mượt 60fps.
  static void precacheIslandSprites(BuildContext context) {
    if (_precached) return;
    _precached = true;
    for (final path in allCoreSprites) {
      precacheImage(AssetImage(path), context);
    }
  }

  /// Tra cứu đường dẫn asset cục bộ hoặc URL backend cho công trình
  static String? resolveBuildingAssetPath(String? renderKey, String? code, [String? assetId]) {
    return resolveIslandAsset(renderKey, code, assetId);
  }

  /// Tra cứu URL từ xa backend an toàn
  static String? resolveBuildingRemoteUrl(String? renderKey, String? assetId) {
    return resolveIslandRemoteAssetUrl(assetId) ?? resolveIslandRemoteAssetUrl(renderKey);
  }

  /// Kiểm tra xem tile có gắn tiểu cảnh môi trường tự nhiên không
  static bool hasSceneryVisual(IslandTileDto tile) {
    if (tile.decorKey != null && tile.decorKey!.isNotEmpty) return true;
    if (tile.terrainType == IslandTerrainType.decorative) return true;
    return false;
  }

  /// Trả về đường dẫn sprite mặt đất hình thoi 2:1 tương ứng với từng ô tile.
  static String resolveTerrainTileSprite(IslandTileDto tile) {
    switch (tile.terrainType) {
      case IslandTerrainType.dirt:
        return dirtCourtyardTile;
      case IslandTerrainType.path:
        return villagePathTile;
      case IslandTerrainType.stone:
      case IslandTerrainType.sand:
        return stoneTerraceTile;
      case IslandTerrainType.grass:
      case IslandTerrainType.decorative:
      case IslandTerrainType.water:
        final variant = (tile.row * 7 + tile.col * 13).abs() % 3;
        if (variant == 1) return grassTile02;
        if (variant == 2) return grassTile03;
        return grassTile01;
    }
  }

  /// Trả về màu sắc nền phụ trợ và vách bờ địa hình cho từng loại Terrain
  static ({
    Color base,
    Color highlight,
    Color shadow,
    Color rimLight,
  }) getTerrainPalette(IslandTerrainType terrain, {int row = 0, int col = 0, bool isLocked = false}) {
    if (isLocked) {
      return (
        base: const Color(0xFF6B8280),
        highlight: const Color(0xFF839B98),
        shadow: const Color(0xFF4C615F),
        rimLight: const Color(0xFF9EB4B2),
      );
    }

    final seed = math.sin(row * 12.9898 + col * 78.233) * 43758.5453;
    final jitter = (seed - seed.floor()) - 0.5;

    switch (terrain) {
      case IslandTerrainType.grass:
      case IslandTerrainType.decorative:
        final r = (0x7D + (jitter * 8).round()).clamp(0x72, 0x8A);
        final g = (0xA8 + (jitter * 8).round()).clamp(0x9C, 0xB4);
        final b = (0x4F + (jitter * 6).round()).clamp(0x46, 0x58);
        return (
          base: Color.fromARGB(255, r, g, b),
          highlight: const Color(0xFF98C268),
          shadow: const Color(0xFF628B3B),
          rimLight: const Color(0xFFB3DA82),
        );

      case IslandTerrainType.dirt:
        return (
          base: const Color(0xFF9E6E47),
          highlight: const Color(0xFFB9865D),
          shadow: const Color(0xFF7D5333),
          rimLight: const Color(0xFFD09E74),
        );

      case IslandTerrainType.path:
        return (
          base: const Color(0xFF84A652),
          highlight: const Color(0xFF9EC069),
          shadow: const Color(0xFF658539),
          rimLight: const Color(0xFFB6D582),
        );

      case IslandTerrainType.stone:
        return (
          base: const Color(0xFF6E7F79),
          highlight: const Color(0xFF899B95),
          shadow: const Color(0xFF53635E),
          rimLight: const Color(0xFFA2B3AD),
        );

      case IslandTerrainType.sand:
        return (
          base: const Color(0xFFD9C07A),
          highlight: const Color(0xFFEED792),
          shadow: const Color(0xFFBBA35F),
          rimLight: const Color(0xFFF9E7AC),
        );

      case IslandTerrainType.water:
        return (
          base: const Color(0xFF5CAFB9),
          highlight: const Color(0xFF7AC9D2),
          shadow: const Color(0xFF3D8C9F),
          rimLight: const Color(0xFF9CE0E8),
        );
    }
  }

  /// Tra cứu thông số sprite 2.5D cho tiểu cảnh dựa vào visualKey và tọa độ tile.
  static IslandScenerySpriteSpec resolveScenerySpec(
    String? visualKey, {
    int row = 0,
    int col = 0,
  }) {
    final key = (visualKey ?? '').toLowerCase().trim();
    // Biến thiên tỷ lệ rất nhẹ theo tọa độ để tạo nhịp điệu thị giác tự nhiên
    final scaleJitter = 0.96 + ((row * 5 + col * 3).abs() % 5) * 0.025;

    if (key.contains('bamboo') || key.contains('tre')) {
      final useSmall = (row + col).isOdd;
      if (useSmall) {
        return IslandScenerySpriteSpec(
          assetPath: bambooGroveSmall,
          widthFactor: 0.86 * scaleJitter,
          heightFactor: 2.15 * scaleJitter,
          bottomPadFactor: 0.08,
          shadowWidthFactor: 0.54,
          shadowHeightFactor: 0.30,
          shadowOpacity: 0.26,
        );
      }
      return IslandScenerySpriteSpec(
        assetPath: bambooGroveLarge,
        widthFactor: 1.12 * scaleJitter,
        heightFactor: 2.45 * scaleJitter,
        bottomPadFactor: 0.06,
        shadowWidthFactor: 0.72,
        shadowHeightFactor: 0.38,
        shadowOpacity: 0.28,
      );
    }

    if (key.contains('lotus') || key.contains('sen')) {
      return const IslandScenerySpriteSpec(
        assetPath: lotusPondCluster,
        widthFactor: 1.12,
        heightFactor: 1.36,
        bottomPadFactor: 0.02,
        shadowWidthFactor: 0.82,
        shadowHeightFactor: 0.42,
        shadowOpacity: 0.20,
      );
    }

    if (key.contains('rice') || key.contains('lua')) {
      return const IslandScenerySpriteSpec(
        assetPath: ricePaddyPatch,
        widthFactor: 1.08,
        heightFactor: 1.32,
        bottomPadFactor: 0.02,
        shadowWidthFactor: 0.78,
        shadowHeightFactor: 0.38,
        shadowOpacity: 0.18,
      );
    }

    if (key.contains('lantern') || key.contains('lamp') || key.contains('den')) {
      return IslandScenerySpriteSpec(
        assetPath: stoneLantern,
        widthFactor: 0.68 * scaleJitter,
        heightFactor: 1.92 * scaleJitter,
        bottomPadFactor: 0.08,
        shadowWidthFactor: 0.48,
        shadowHeightFactor: 0.28,
        shadowOpacity: 0.28,
      );
    }

    if (key.contains('well') || key.contains('gieng')) {
      return const IslandScenerySpriteSpec(
        assetPath: ancientStoneWell,
        widthFactor: 0.96,
        heightFactor: 1.56,
        bottomPadFactor: 0.06,
        shadowWidthFactor: 0.70,
        shadowHeightFactor: 0.38,
        shadowOpacity: 0.26,
      );
    }

    if (key.contains('clay') || key.contains('brick') || key.contains('jar') || key.contains('fence')) {
      final useWell = (row + col).isEven;
      if (useWell) {
        return const IslandScenerySpriteSpec(
          assetPath: ancientStoneWell,
          widthFactor: 0.94,
          heightFactor: 1.52,
          bottomPadFactor: 0.06,
          shadowWidthFactor: 0.68,
          shadowHeightFactor: 0.36,
          shadowOpacity: 0.26,
        );
      }
      return const IslandScenerySpriteSpec(
        assetPath: terracottaJarsFence,
        widthFactor: 0.95,
        heightFactor: 1.68,
        bottomPadFactor: 0.06,
        shadowWidthFactor: 0.68,
        shadowHeightFactor: 0.36,
        shadowOpacity: 0.26,
      );
    }

    if (key.contains('banyan') || key.contains('tree') || key.contains('cay') || key.contains('sapling')) {
      return IslandScenerySpriteSpec(
        assetPath: banyanSapling,
        widthFactor: 1.26 * scaleJitter,
        heightFactor: 2.55 * scaleJitter,
        bottomPadFactor: 0.06,
        shadowWidthFactor: 0.80,
        shadowHeightFactor: 0.42,
        shadowOpacity: 0.32,
      );
    }

    if (key.contains('shrub') || key.contains('bush')) {
      return IslandScenerySpriteSpec(
        assetPath: floweringShrub,
        widthFactor: 0.94 * scaleJitter,
        heightFactor: 1.68 * scaleJitter,
        bottomPadFactor: 0.06,
        shadowWidthFactor: 0.66,
        shadowHeightFactor: 0.34,
        shadowOpacity: 0.25,
      );
    }

    if (key.contains('rock') || key.contains('stone') || key.contains('da')) {
      return IslandScenerySpriteSpec(
        assetPath: mossyRockCluster,
        widthFactor: 0.98 * scaleJitter,
        heightFactor: 1.78 * scaleJitter,
        bottomPadFactor: 0.05,
        shadowWidthFactor: 0.72,
        shadowHeightFactor: 0.38,
        shadowOpacity: 0.28,
      );
    }

    if (key.contains('flower') || key.contains('hoa')) {
      return const IslandScenerySpriteSpec(
        assetPath: wildflowersPatch,
        widthFactor: 1.02,
        heightFactor: 1.24,
        bottomPadFactor: 0.02,
        shadowWidthFactor: 0.70,
        shadowHeightFactor: 0.34,
        shadowOpacity: 0.16,
      );
    }

    return IslandScenerySpriteSpec(
      assetPath: floweringShrub,
      widthFactor: 0.90 * scaleJitter,
      heightFactor: 1.60 * scaleJitter,
      bottomPadFactor: 0.06,
    );
  }

  /// Render tiểu cảnh 2.5D bằng sprite minh họa thật kèm bóng tiếp đất mềm mại.
  static Widget renderSceneryItem({
    required String? visualKey,
    required double tileWidth,
    required double tileHeight,
    int row = 0,
    int col = 0,
    bool isLocked = false,
  }) {
    final spec = resolveScenerySpec(visualKey, row: row, col: col);
    final spriteW = tileWidth * spec.widthFactor;
    final spriteH = tileHeight * spec.heightFactor;
    final shadowW = tileWidth * spec.shadowWidthFactor;
    final shadowH = tileHeight * spec.shadowHeightFactor;

    Widget art = Image.asset(
      spec.assetPath,
      width: spriteW,
      height: spriteH,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.medium,
    );

    if (isLocked) {
      art = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.42, 0.28, 0.18, 0, 28,
          0.22, 0.48, 0.20, 0, 36,
          0.22, 0.30, 0.46, 0, 44,
          0,    0,    0,    0.72, 0,
        ]),
        child: art,
      );
    }

    return SizedBox(
      width: spriteW,
      height: spriteH + tileHeight * spec.bottomPadFactor,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Bóng đổ tiếp đất (Ambient Occlusion)
          Positioned(
            bottom: tileHeight * (spec.bottomPadFactor * 0.6),
            child: Container(
              width: shadowW,
              height: shadowH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.elliptical(shadowW, shadowH),
                ),
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E2D24).withValues(
                      alpha: isLocked ? spec.shadowOpacity * 0.5 : spec.shadowOpacity,
                    ),
                    const Color(0xFF1E2D24).withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.62, 1.0],
                ),
              ),
            ),
          ),
          // Sprite 2.5D
          Positioned(
            bottom: tileHeight * spec.bottomPadFactor,
            child: art,
          ),
        ],
      ),
    );
  }
}
