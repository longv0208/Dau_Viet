import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../data/island_dto.dart';

/// 4 góc nhìn Isometric cố định (Discrete Isometric Viewpoints — 10A)
/// cho phép người chơi xoay quanh Đảo Di Sản mượt mà mà vẫn bảo toàn tuyệt đối
/// chiều sâu Painter's Algorithm, vách đá bờ biển, ánh sáng và Hit Testing.
enum IslandCameraDirection {
  northEast(0, 'Đông Bắc', 'ĐB', 0),
  southEast(1, 'Đông Nam', 'ĐN', 90),
  southWest(2, 'Tây Nam', 'TN', 180),
  northWest(3, 'Tây Bắc', 'TB', 270);

  final int quarterTurns;
  final String labelVi;
  final String shortCode;
  final int degrees;

  const IslandCameraDirection(
    this.quarterTurns,
    this.labelVi,
    this.shortCode,
    this.degrees,
  );

  /// Xoay sang góc nhìn tiếp theo theo chiều kim đồng hồ (+90°)
  IslandCameraDirection get nextClockwise =>
      IslandCameraDirection.values[(quarterTurns + 1) % 4];

  /// Xoay sang góc nhìn tiếp theo ngược chiều kim đồng hồ (-90°)
  IslandCameraDirection get nextCounterClockwise =>
      IslandCameraDirection.values[(quarterTurns + 3) % 4];

  /// Chuyển đổi tọa độ logic (row, col) của tile sang tọa độ lưới theo góc nhìn (vRow, vCol).
  (int vRow, int vCol) toViewCoord(
    int row,
    int col, {
    required int rows,
    required int cols,
  }) {
    final maxR = math.max(rows - 1, 0);
    final maxC = math.max(cols - 1, 0);
    switch (this) {
      case IslandCameraDirection.northEast:
        return (row, col);
      case IslandCameraDirection.southEast:
        return (col, maxR - row);
      case IslandCameraDirection.southWest:
        return (maxR - row, maxC - col);
      case IslandCameraDirection.northWest:
        return (maxC - col, row);
    }
  }

  /// Xoay 4 hướng kết nối cạnh hình thoi (N, E, S, W logic) sang 4 cạnh màn hình (NE, SE, SW, NW).
  ({bool ne, bool se, bool sw, bool nw}) rotateConnections({
    required bool n,
    required bool e,
    required bool s,
    required bool w,
  }) {
    switch (this) {
      case IslandCameraDirection.northEast:
        return (ne: n, se: e, sw: s, nw: w);
      case IslandCameraDirection.southEast:
        return (ne: w, se: n, sw: e, nw: s);
      case IslandCameraDirection.southWest:
        return (ne: s, se: w, sw: n, nw: e);
      case IslandCameraDirection.northWest:
        return (ne: e, se: s, sw: w, nw: n);
    }
  }
}

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
  final bool allowDirectionalFlip;

  const IslandScenerySpriteSpec({
    required this.assetPath,
    this.widthFactor = 1.0,
    this.heightFactor = 1.8,
    this.bottomPadFactor = 0.10,
    this.shadowWidthFactor = 0.56,
    this.shadowHeightFactor = 0.34,
    this.shadowOpacity = 0.24,
    this.allowDirectionalFlip = true,
  });
}

/// Quản lý tập trung toàn bộ Visual Assets (PNG 2.5D Sprites) & Hệ thống Autotiling Đường Làng (10B).
class IslandVisualAssetManager {
  IslandVisualAssetManager._();

  // --- Base Terrain Tiles ---
  static const String grassTile01 = 'assets/island/terrain/tile_grass_01.png';
  static const String grassTile02 = 'assets/island/terrain/tile_grass_02.png';
  static const String grassTile03 = 'assets/island/terrain/tile_grass_03.png';
  static const String dirtCourtyardTile = 'assets/island/terrain/tile_dirt_courtyard.png';
  static const String villagePathTile = 'assets/island/terrain/tile_village_path.png';
  static const String stoneTerraceTile = 'assets/island/terrain/tile_stone_terrace.png';

  // --- Autotiled Brick Path & Village Plaza Family (10B) ---
  static const String pathStraightNeSw01 = 'assets/island/terrain/path_straight_ne_sw_01.png';
  static const String pathStraightNeSw02 = 'assets/island/terrain/path_straight_ne_sw_02.png';
  static const String pathStraightNwSe01 = 'assets/island/terrain/path_straight_nw_se_01.png';
  static const String pathStraightNwSe02 = 'assets/island/terrain/path_straight_nw_se_02.png';

  static const String pathCornerNeSe = 'assets/island/terrain/path_corner_ne_se.png';
  static const String pathCornerSeSw = 'assets/island/terrain/path_corner_se_sw.png';
  static const String pathCornerSwNw = 'assets/island/terrain/path_corner_sw_nw.png';
  static const String pathCornerNwNe = 'assets/island/terrain/path_corner_nw_ne.png';

  static const String pathTjunctionNoNw = 'assets/island/terrain/path_tjunction_no_nw.png';
  static const String pathTjunctionNoNe = 'assets/island/terrain/path_tjunction_no_ne.png';
  static const String pathTjunctionNoSe = 'assets/island/terrain/path_tjunction_no_se.png';
  static const String pathTjunctionNoSw = 'assets/island/terrain/path_tjunction_no_sw.png';

  static const String pathCrossroad01 = 'assets/island/terrain/path_crossroad_01.png';
  static const String pathCrossroad02 = 'assets/island/terrain/path_crossroad_02.png';

  static const String pathEndcapNe = 'assets/island/terrain/path_endcap_ne.png';
  static const String pathEndcapSe = 'assets/island/terrain/path_endcap_se.png';
  static const String pathEndcapSw = 'assets/island/terrain/path_endcap_sw.png';
  static const String pathEndcapNw = 'assets/island/terrain/path_endcap_nw.png';

  static const String pathPlazaCenter01 = 'assets/island/terrain/path_plaza_center_01.png';
  static const String pathPlazaCenter02 = 'assets/island/terrain/path_plaza_center_02.png';
  static const String pathPlazaQuadNw = 'assets/island/terrain/path_plaza_quad_nw.png';
  static const String pathPlazaQuadNwAlt = 'assets/island/terrain/path_plaza_quad_nw_alt.png';
  static const String pathPlazaQuadNe = 'assets/island/terrain/path_plaza_quad_ne.png';
  static const String pathPlazaQuadNeAlt = 'assets/island/terrain/path_plaza_quad_ne_alt.png';
  static const String pathPlazaQuadSe = 'assets/island/terrain/path_plaza_quad_se.png';
  static const String pathPlazaQuadSeAlt = 'assets/island/terrain/path_plaza_quad_se_alt.png';
  static const String pathPlazaQuadSw = 'assets/island/terrain/path_plaza_quad_sw.png';
  static const String pathPlazaQuadSwAlt = 'assets/island/terrain/path_plaza_quad_sw_alt.png';

  static const String pathTransitionGrass = 'assets/island/terrain/path_transition_grass.png';
  static const String pathTransitionStone = 'assets/island/terrain/path_transition_stone.png';

  // --- 2.5D Scenery & Parcel Plinth Sprites ---
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
    pathStraightNeSw01,
    pathStraightNeSw02,
    pathStraightNwSe01,
    pathStraightNwSe02,
    pathCornerNeSe,
    pathCornerSeSw,
    pathCornerSwNw,
    pathCornerNwNe,
    pathTjunctionNoNw,
    pathTjunctionNoNe,
    pathTjunctionNoSe,
    pathTjunctionNoSw,
    pathCrossroad01,
    pathCrossroad02,
    pathEndcapNe,
    pathEndcapSe,
    pathEndcapSw,
    pathEndcapNw,
    pathPlazaCenter01,
    pathPlazaCenter02,
    pathPlazaQuadNw,
    pathPlazaQuadNwAlt,
    pathPlazaQuadNe,
    pathPlazaQuadNeAlt,
    pathPlazaQuadSe,
    pathPlazaQuadSeAlt,
    pathPlazaQuadSw,
    pathPlazaQuadSwAlt,
    pathTransitionGrass,
    pathTransitionStone,
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
    'assets/island/scenery/cay_da_co_thu.png',
    'assets/island/buildings/nha_rong.png',
    'assets/island/buildings/dinh_lang.png',
    'assets/island/buildings/chua_co.png',
    'assets/island/buildings/thap_cham.png',
    'assets/island/buildings/cot_co.png',
    'assets/island/buildings/buc_tuong.png',
    'assets/island/buildings/cong_lang.png',
    'assets/island/buildings/khue_van_cac.png',
    'assets/island/buildings/thap_but.png',
    'assets/island/buildings/choi_canh_bach_dang.png',
    'assets/island/buildings/coc_bach_dang.png',
    'assets/island/buildings/trong_dong_dong_son.png',
    'assets/island/buildings/thanh_nha_ho.png',
    'assets/island/buildings/co_loa.png',
    'assets/island/buildings/pho_hoi_an.png',
    'assets/island/buildings/no_lien_chau.png',
    'assets/island/buildings/thuyen_chien_ngo_quyen.png',
    'assets/island/buildings/chieu_doi_do.png',
  ];

  static bool _precached = false;

  /// Precache toàn bộ sprite cốt lõi vào bộ nhớ đệm hình ảnh để cuộn/zoom/xoay mượt 60fps.
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

  /// Trả về sprite cỏ tự nhiên có biến thiên theo tọa độ
  static String _resolveGrassVariant(int row, int col) {
    final variant = (row * 7 + col * 13).abs() % 3;
    if (variant == 1) return grassTile02;
    if (variant == 2) return grassTile03;
    return grassTile01;
  }

  /// Hệ thống Autotiling Đường Làng & Quảng Trường Gạch (10B) kết hợp Góc Nhìn Camera (10A).
  /// Tự động xét các ô lân cận (N, E, S, W) trên bàn cờ để chọn đúng biến thể đường gạch:
  /// - Đoạn thẳng (NE-SW / NW-SE, 2 biến thể chống lặp)
  /// - Khúc cua 90° (4 hướng)
  /// - Ngã ba chữ T có phù điêu hoa sen (4 hướng)
  /// - Ngã tư giao lộ (2 biến thể)
  /// - Đầu đường / điểm kết thúc (4 hướng)
  /// - Quảng trường sân đình trung tâm ghép 4 góc tròn liền mạch
  /// - Đoạn chuyển tiếp sang bậc đá xanh & lối cỏ vườn
  static String resolveAutotiledTerrainSprite({
    required IslandTileDto tile,
    required Map<(int, int), IslandTileDto> tileMap,
    IslandCameraDirection cameraDirection = IslandCameraDirection.northEast,
  }) {
    final r = tile.row;
    final c = tile.col;

    switch (tile.terrainType) {
      case IslandTerrainType.stone:
        return stoneTerraceTile;
      case IslandTerrainType.sand:
        // Bãi cát vàng ấm ven bờ — dùng nền sân đất ấm áp thay thềm đá lạnh
        return dirtCourtyardTile;

      case IslandTerrainType.dirt:
        // Nếu ô DIRT là nền đặt slot xây dựng đơn lẻ (như trong fixture fallback),
        // dùng nền cỏ tự nhiên để bệ đá hoa sen (buildable_parcel_plinth) nổi bật hài hòa.
        final bool hasSlot = tile.slotId != null && tile.slotId!.isNotEmpty;
        final bool nIsPlaza = _isCourtyardPlazaTile(tileMap[(r - 1, c)]);
        final bool eIsPlaza = _isCourtyardPlazaTile(tileMap[(r, c + 1)]);
        final bool sIsPlaza = _isCourtyardPlazaTile(tileMap[(r + 1, c)]);
        final bool wIsPlaza = _isCourtyardPlazaTile(tileMap[(r, c - 1)]);

        if (hasSlot && !nIsPlaza && !eIsPlaza && !sIsPlaza && !wIsPlaza) {
          return _resolveGrassVariant(r, c);
        }

        // Xác định 4 góc của quảng trường 2x2 xoay theo góc nhìn camera hiện tại
        final rotPlaza = cameraDirection.rotateConnections(
          n: nIsPlaza,
          e: eIsPlaza,
          s: sIsPlaza,
          w: wIsPlaza,
        );
        final bool isOddRotation =
            cameraDirection == IslandCameraDirection.southEast ||
            cameraDirection == IslandCameraDirection.northWest;

        if (rotPlaza.se && rotPlaza.sw) {
          return isOddRotation ? pathPlazaQuadNwAlt : pathPlazaQuadNw;
        }
        if (rotPlaza.sw && rotPlaza.nw) {
          return isOddRotation ? pathPlazaQuadNeAlt : pathPlazaQuadNe;
        }
        if (rotPlaza.nw && rotPlaza.ne) {
          return isOddRotation ? pathPlazaQuadSeAlt : pathPlazaQuadSe;
        }
        if (rotPlaza.ne && rotPlaza.se) {
          return isOddRotation ? pathPlazaQuadSwAlt : pathPlazaQuadSw;
        }
        return (r + c).isEven ? pathPlazaCenter01 : pathPlazaCenter02;

      case IslandTerrainType.path:
        final logical = _resolveLogicalPathConnections(tile, tileMap);
        final viewConn = cameraDirection.rotateConnections(
          n: logical.n,
          e: logical.e,
          s: logical.s,
          w: logical.w,
        );

        // Chuyển tiếp mềm sang thềm đá hoặc lối nhỏ sân vườn khi phù hợp
        if (logical.specialMode == 'transition_stone' &&
            viewConn.ne &&
            viewConn.sw &&
            !viewConn.nw &&
            !viewConn.se) {
          return pathTransitionStone;
        }
        if (logical.specialMode == 'transition_grass' &&
            viewConn.ne &&
            viewConn.sw &&
            !viewConn.nw &&
            !viewConn.se) {
          return pathTransitionGrass;
        }

        return _selectRoadSpriteForViewConnections(
          ne: viewConn.ne,
          se: viewConn.se,
          sw: viewConn.sw,
          nw: viewConn.nw,
          row: r,
          col: c,
        );

      case IslandTerrainType.grass:
      case IslandTerrainType.decorative:
      case IslandTerrainType.water:
        return _resolveGrassVariant(r, c);
    }
  }

  /// Giữ hàm tương thích ngược nếu gọi đơn lẻ không truyền map
  static String resolveTerrainTileSprite(IslandTileDto tile) {
    return resolveAutotiledTerrainSprite(
      tile: tile,
      tileMap: {(tile.row, tile.col): tile},
    );
  }

  static bool _isCourtyardPlazaTile(IslandTileDto? t) {
    if (t == null) return false;
    return t.terrainType == IslandTerrainType.dirt &&
        (t.slotId == null || t.slotId!.isEmpty);
  }

  static bool _isPathTile(IslandTileDto? t) =>
      t != null && t.terrainType == IslandTerrainType.path;

  static bool _isRoadOrSlotNeighbor(IslandTileDto? t) {
    if (t == null) return false;
    if (t.terrainType == IslandTerrainType.path ||
        t.terrainType == IslandTerrainType.stone ||
        _isCourtyardPlazaTile(t)) {
      return true;
    }
    return t.slotId != null && t.slotId!.isNotEmpty;
  }

  /// Phân tích cấu trúc kết nối đường làng (N, E, S, W) cho ô PATH.
  /// Xử lý thông minh cả cụm đại lộ 2x2 (tránh lặp 4 ô giống hệt nhau) lẫn đường đơn 1 ô.
  static ({bool n, bool e, bool s, bool w, String? specialMode})
      _resolveLogicalPathConnections(
    IslandTileDto tile,
    Map<(int, int), IslandTileDto> tileMap,
  ) {
    final r = tile.row;
    final c = tile.col;

    // Kiểm tra xem tile có nằm trong cụm 2x2 PATH không (ví dụ đại lộ Bắc {2..3, 4..5} hoặc Nam {6..7, 4..5})
    int? boxR0;
    int? boxC0;
    for (final dr in [-1, 0]) {
      for (final dc in [-1, 0]) {
        final r0 = r + dr;
        final c0 = c + dc;
        if (_isPathTile(tileMap[(r0, c0)]) &&
            _isPathTile(tileMap[(r0, c0 + 1)]) &&
            _isPathTile(tileMap[(r0 + 1, c0)]) &&
            _isPathTile(tileMap[(r0 + 1, c0 + 1)])) {
          boxR0 = r0;
          boxC0 = c0;
          break;
        }
      }
      if (boxR0 != null) break;
    }

    if (boxR0 != null && boxC0 != null) {
      final isTop = r == boxR0;
      final isLeft = c == boxC0;
      final southBordersPlaza = _isCourtyardPlazaTile(tileMap[(boxR0 + 2, boxC0)]) ||
          _isCourtyardPlazaTile(tileMap[(boxR0 + 2, boxC0 + 1)]);

      if (southBordersPlaza) {
        // Cụm đường phía Bắc dẫn từ Quảng Trường Trung Tâm lên Thềm Đá Bắc
        if (!isTop && isLeft) {
          // (3,4): Ngã ba chữ T nối từ Quảng Trường (S) đi thẳng lên (2,4) (N) và rẽ nhánh sang (3,5) (E)
          return (n: true, e: true, s: true, w: false, specialMode: null);
        } else if (isTop && isLeft) {
          // (2,4): Đường thẳng trục chính từ (3,4) (S) lên Thềm Đá (1,4) (N)
          return (n: true, e: false, s: true, w: false, specialMode: null);
        } else if (!isTop && !isLeft) {
          // (3,5): Ngã rẽ chữ T / khúc cua đón nhánh từ (3,4) (W), dẫn vào Slot (3,6) (E) và lên (2,5) (N)
          final hasEastSlot = _isRoadOrSlotNeighbor(tileMap[(r, c + 1)]);
          return (
            n: true,
            e: hasEastSlot,
            s: false,
            w: true,
            specialMode: null,
          );
        } else {
          // (2,5): Lối vườn chuyển tiếp từ (3,5) (S) lên Thềm Đá (1,5) (N)
          return (
            n: true,
            e: false,
            s: true,
            w: false,
            specialMode: 'transition_stone',
          );
        }
      } else {
        // Cụm đường phía Nam dẫn từ Quảng Trường Trung Tâm xuống Thềm Đá Nam
        if (isTop && !isLeft) {
          // (6,5): Ngã ba chữ T nối từ Quảng Trường (N) đi thẳng xuống (7,5) (S) và rẽ nhánh sang (6,4) (W)
          return (n: true, e: false, s: true, w: true, specialMode: null);
        } else if (!isTop && !isLeft) {
          // (7,5): Đường thẳng trục chính từ (6,5) (N) xuống Thềm Đá (8,5) (S)
          return (n: true, e: false, s: true, w: false, specialMode: null);
        } else if (isTop && isLeft) {
          // (6,4): Ngã rẽ đón nhánh từ (6,5) (E), dẫn vào Slot (6,3) (W) và xuống (7,4) (S)
          final hasWestSlot = _isRoadOrSlotNeighbor(tileMap[(r, c - 1)]);
          return (
            n: false,
            e: true,
            s: true,
            w: hasWestSlot,
            specialMode: null,
          );
        } else {
          // (7,4): Lối vườn lát gạch chuyển tiếp xuống Thềm Đá (8,4) (S)
          return (
            n: true,
            e: false,
            s: true,
            w: false,
            specialMode: 'transition_grass',
          );
        }
      }
    }

    // Trường hợp tổng quát cho mọi đường làng 1 ô (Straight, Corner, T-Junction, Crossroad, End-cap)
    bool n = _isPrimaryPathNeighbor(tileMap[(r - 1, c)]);
    bool e = _isPrimaryPathNeighbor(tileMap[(r, c + 1)]);
    bool s = _isPrimaryPathNeighbor(tileMap[(r + 1, c)]);
    bool w = _isPrimaryPathNeighbor(tileMap[(r, c - 1)]);

    final count = (n ? 1 : 0) + (e ? 1 : 0) + (s ? 1 : 0) + (w ? 1 : 0);
    if (count < 2) {
      // Nếu là nhánh đường cụt hoặc đường vườn ngắn (như (4,2) và (5,7)),
      // nối thêm tới ô Slot xây dựng hoặc tiểu cảnh liền kề để dẫn mắt tự nhiên
      if (!n && _isSlotOrGardenTarget(tileMap[(r - 1, c)])) n = true;
      if (!e && _isSlotOrGardenTarget(tileMap[(r, c + 1)])) e = true;
      if (!s && _isSlotOrGardenTarget(tileMap[(r + 1, c)])) s = true;
      if (!w && _isSlotOrGardenTarget(tileMap[(r, c - 1)])) w = true;
    }

    return (n: n, e: e, s: s, w: w, specialMode: null);
  }

  static bool _isPrimaryPathNeighbor(IslandTileDto? t) {
    if (t == null) return false;
    return t.terrainType == IslandTerrainType.path ||
        t.terrainType == IslandTerrainType.stone ||
        _isCourtyardPlazaTile(t);
  }

  static bool _isSlotOrGardenTarget(IslandTileDto? t) {
    if (t == null) return false;
    if (t.slotId != null && t.slotId!.isNotEmpty) return true;
    final dk = (t.decorKey ?? '').toLowerCase();
    return dk.contains('rice') || dk.contains('lotus') || dk.contains('well');
  }

  /// Ánh xạ 4 hướng kết nối màn hình (ne, se, sw, nw) sang đúng file PNG trong bộ 28 sprite đường làng.
  static String _selectRoadSpriteForViewConnections({
    required bool ne,
    required bool se,
    required bool sw,
    required bool nw,
    required int row,
    required int col,
  }) {
    final count = (ne ? 1 : 0) + (se ? 1 : 0) + (sw ? 1 : 0) + (nw ? 1 : 0);
    final alt = (row * 3 + col * 5).abs() % 2 == 1;

    if (count == 4) {
      return alt ? pathCrossroad02 : pathCrossroad01;
    }

    if (count == 3) {
      if (!nw) return pathTjunctionNoNw;
      if (!ne) return pathTjunctionNoNe;
      if (!se) return pathTjunctionNoSe;
      return pathTjunctionNoSw;
    }

    if (count == 2) {
      if (ne && sw) {
        return alt ? pathStraightNeSw02 : pathStraightNeSw01;
      }
      if (nw && se) {
        return alt ? pathStraightNwSe02 : pathStraightNwSe01;
      }
      if (ne && se) return pathCornerNeSe;
      if (se && sw) return pathCornerSeSw;
      if (sw && nw) return pathCornerSwNw;
      return pathCornerNwNe;
    }

    if (count == 1) {
      if (ne) return pathEndcapNe;
      if (se) return pathEndcapSe;
      if (sw) return pathEndcapSw;
      return pathEndcapNw;
    }

    return alt ? pathStraightNeSw02 : pathStraightNeSw01;
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
      case IslandTerrainType.path:
      case IslandTerrainType.dirt:
        final r = (0x7D + (jitter * 8).round()).clamp(0x72, 0x8A);
        final g = (0xA8 + (jitter * 8).round()).clamp(0x9C, 0xB4);
        final b = (0x4F + (jitter * 6).round()).clamp(0x46, 0x58);
        return (
          base: Color.fromARGB(255, r, g, b),
          highlight: const Color(0xFF98C268),
          shadow: const Color(0xFF628B3B),
          rimLight: const Color(0xFFB3DA82),
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
    final scaleJitter = 0.96 + ((row * 5 + col * 3).abs() % 5) * 0.025;

    // Hồ nước ngọc nhận thác — mặt nước phẳng phản quang
    if (key.contains('pool')) {
      return const IslandScenerySpriteSpec(
        assetPath: lotusPondCluster,
        widthFactor: 1.16,
        heightFactor: 1.42,
        bottomPadFactor: 0.02,
        shadowWidthFactor: 0.86,
        shadowHeightFactor: 0.44,
        shadowOpacity: 0.20,
      );
    }

    // Cầu tàu gỗ — thềm gỗ thò ra nước, thấp và dẹt
    if (key.contains('dock')) {
      return const IslandScenerySpriteSpec(
        assetPath: terracottaJarsFence,
        widthFactor: 1.12,
        heightFactor: 1.10,
        bottomPadFactor: 0.02,
        shadowWidthFactor: 0.84,
        shadowHeightFactor: 0.36,
        shadowOpacity: 0.22,
      );
    }

    // Thuyền gỗ neo cạnh cầu tàu — dáng dài, mạn thuyền cong
    if (key.contains('boat')) {
      return const IslandScenerySpriteSpec(
        assetPath: terracottaJarsFence,
        widthFactor: 1.22,
        heightFactor: 1.05,
        bottomPadFactor: 0.01,
        shadowWidthFactor: 0.92,
        shadowHeightFactor: 0.38,
        shadowOpacity: 0.24,
      );
    }

    // Thác nước trên vách đá — dùng cụm đá rêu làm khối nền cho painter vẽ thác
    if (key.contains('waterfall')) {
      return IslandScenerySpriteSpec(
        assetPath: mossyRockCluster,
        widthFactor: 1.42 * scaleJitter,
        heightFactor: 2.30 * scaleJitter,
        bottomPadFactor: 0.04,
        shadowWidthFactor: 0.90,
        shadowHeightFactor: 0.42,
        shadowOpacity: 0.32,
      );
    }

    // Cụm cọ / dừa nhiệt đới trên đồi cỏ & rìa đảo — dáng cao, tán tỏa
    if (key.contains('palm')) {
      return IslandScenerySpriteSpec(
        assetPath: banyanSapling,
        widthFactor: 1.30 * scaleJitter,
        heightFactor: 2.62 * scaleJitter,
        bottomPadFactor: 0.05,
        shadowWidthFactor: 0.82,
        shadowHeightFactor: 0.44,
        shadowOpacity: 0.32,
      );
    }

    // Cọc đá / hòn phụ trên vành nước — khối đá rêu phong lởm chởm
    if (key.contains('islet') || key.contains('sea_stack')) {
      return IslandScenerySpriteSpec(
        assetPath: mossyRockCluster,
        widthFactor: 1.18 * scaleJitter,
        heightFactor: 1.92 * scaleJitter,
        bottomPadFactor: 0.03,
        shadowWidthFactor: 0.88,
        shadowHeightFactor: 0.40,
        shadowOpacity: 0.30,
      );
    }

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
        allowDirectionalFlip: false,
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
    IslandCameraDirection cameraDirection = IslandCameraDirection.northEast,
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

    // Khi xoay góc nhìn sang hướng đối xứng, phản chiếu nhẹ các cụm cây/đá để dáng tự nhiên
    if (spec.allowDirectionalFlip &&
        (cameraDirection == IslandCameraDirection.southEast ||
            cameraDirection == IslandCameraDirection.southWest)) {
      art = Transform.flip(
        flipX: true,
        child: art,
      );
    }

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
