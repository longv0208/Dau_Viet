import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Trả về đường dẫn asset cục bộ đã đóng gói dựa vào renderKey hoặc code.
/// Trả về null nếu vật phẩm chưa có tranh minh họa cục bộ tương ứng —
/// tuyệt đối KHÔNG biến mọi vật phẩm lạ thành `decor_nha_tranh.png`.
String? resolveIslandAsset(String? renderKey, String? code, [String? assetId]) {
  final rk = (renderKey ?? '').toLowerCase().trim();
  final cd = (code ?? '').toLowerCase().trim();

  if (rk.startsWith('assets/') && !rk.contains('..')) {
    return renderKey!.trim();
  }

  for (final token in [rk, cd]) {
    if (token.isEmpty) continue;
    if (token == 'decor.nha_tranh' ||
        token == 'decor_nha_tranh' ||
        token == 'nha_tranh') {
      return 'assets/items/decor_nha_tranh.png';
    }
    if (token == 'decor.cau_kieu' ||
        token == 'decor_cau_kieu' ||
        token == 'cau_kieu') {
      return 'assets/items/decor_cau_kieu.png';
    }
    if (token == 'decor.ho_sen' ||
        token == 'decor_ho_sen' ||
        token == 'ho_sen') {
      return 'assets/items/decor_ho_sen.png';
    }
    if (token == 'decor.cay_da' ||
        token == 'decor_cay_da' ||
        token == 'cay_da') {
      return 'assets/items/decor_cay_da.png';
    }
  }
  return null;
}

String _friendlyItemNameFromCode(String? code, String? renderKey) {
  final raw = (code ?? renderKey ?? '').toLowerCase().trim();
  if (raw.contains('cay_da')) return 'Cây đa cổ thụ';
  if (raw.contains('nha_tranh')) return 'Nhà tranh vách đất';
  if (raw.contains('ho_sen')) return 'Hồ sen';
  if (raw.contains('cau_kieu')) return 'Cầu kiều mái cong';
  if (raw.contains('bui_tre')) return 'Bụi Tre Làng Cổ';
  if (raw.contains('gieng_co')) return 'Giếng Cổ Đá Xanh';
  if (raw.contains('cong_lang')) return 'Cổng Làng Đá Ong';
  if (raw.contains('den_long')) return 'Đèn Lồng Phố Cổ';
  if (raw.contains('dinh_lang')) return 'Đình Làng Mái Đao';
  if (raw.contains('thuyen_rong')) return 'Thuyền Rồng Bến Nước';
  if (raw.contains('thap_but')) return 'Tháp Bút Truyền Thống';
  if (raw.contains('khue_van')) return 'Khuê Văn Các Thu Nhỏ';
  return code ?? 'Vật phẩm di sản';
}

/// Thông tin vật phẩm đặt trên một slot của đảo.
@immutable
class IslandPlacementDto {
  final String itemId;
  final String code;
  final String name;
  final String? renderKey;
  final String? assetId;

  const IslandPlacementDto({
    required this.itemId,
    required this.code,
    required this.name,
    this.renderKey,
    this.assetId,
  });

  String? get assetPath => resolveIslandAsset(renderKey, code, assetId);

  factory IslandPlacementDto.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String? ?? '';
    final renderKey = json['renderKey'] as String?;
    final rawName = json['name'] as String?;
    return IslandPlacementDto(
      itemId: json['itemId'] as String? ?? '',
      code: code,
      name: (rawName != null && rawName.isNotEmpty && rawName != code)
          ? rawName
          : _friendlyItemNameFromCode(code, renderKey),
      renderKey: renderKey,
      assetId: json['assetId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'code': code,
    'name': name,
    if (renderKey != null) 'renderKey': renderKey,
    if (assetId != null) 'assetId': assetId,
  };
}

/// Thông tin một slot trên bản đồ đảo di sản isometric.
@immutable
class IslandSlotDto {
  final String slotId;
  final double x;
  final double y;
  final int zIndex;
  final int unlockTier;
  final bool unlocked;
  final List<String> allowedCategories;
  final IslandPlacementDto? placement;
  // V43/V44 layout fields
  final String? stableSlotKey;
  final String? regionCode;
  final double anchorX;
  final double anchorY;
  final double widthNorm;
  final double heightNorm;

  const IslandSlotDto({
    required this.slotId,
    required this.x,
    required this.y,
    this.zIndex = 0,
    this.unlockTier = 1,
    this.unlocked = true,
    this.allowedCategories = const ['DECOR'],
    this.placement,
    this.stableSlotKey,
    this.regionCode,
    this.anchorX = 0.5,
    this.anchorY = 1.0,
    this.widthNorm = 0.10,
    this.heightNorm = 0.12,
  });

  bool get isOccupied => placement != null;
  bool get isEmpty => unlocked && placement == null;
  bool get isLocked => !unlocked;

  IslandSlotDto copyWith({
    String? slotId,
    double? x,
    double? y,
    int? zIndex,
    int? unlockTier,
    bool? unlocked,
    List<String>? allowedCategories,
    IslandPlacementDto? Function()? placement,
    String? stableSlotKey,
    String? regionCode,
    double? anchorX,
    double? anchorY,
    double? widthNorm,
    double? heightNorm,
  }) {
    return IslandSlotDto(
      slotId: slotId ?? this.slotId,
      x: x ?? this.x,
      y: y ?? this.y,
      zIndex: zIndex ?? this.zIndex,
      unlockTier: unlockTier ?? this.unlockTier,
      unlocked: unlocked ?? this.unlocked,
      allowedCategories: allowedCategories ?? this.allowedCategories,
      placement: placement != null ? placement() : this.placement,
      stableSlotKey: stableSlotKey ?? this.stableSlotKey,
      regionCode: regionCode ?? this.regionCode,
      anchorX: anchorX ?? this.anchorX,
      anchorY: anchorY ?? this.anchorY,
      widthNorm: widthNorm ?? this.widthNorm,
      heightNorm: heightNorm ?? this.heightNorm,
    );
  }

  factory IslandSlotDto.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['allowedCategories'];
    // Backend SlotView fields: slotId, slotIndex, tierRequired, unlocked,
    // coordX, coordY, placedItemId, placedItemCode, placedRenderKey, placedAt.
    // Fall-back to legacy field names so MockIslandRepository still works.
    final placedItemId = json['placedItemId'] as String?;
    final placedItemCode = json['placedItemCode'] as String?;
    final placedItemName = json['placedItemName'] as String?;
    final placedRenderKey = json['placedRenderKey'] as String?;
    // Build placement from flat backend fields, or from legacy nested map
    IslandPlacementDto? placement;
    if (placedItemId != null) {
      placement = IslandPlacementDto(
        itemId: placedItemId,
        code: placedItemCode ?? '',
        name: (placedItemName != null &&
                placedItemName.isNotEmpty &&
                placedItemName != placedItemCode)
            ? placedItemName
            : _friendlyItemNameFromCode(placedItemCode, placedRenderKey),
        renderKey: placedRenderKey,
      );
    } else if (json['placement'] is Map) {
      placement = IslandPlacementDto.fromJson(
        (json['placement'] as Map).cast<String, dynamic>(),
      );
    }
    return IslandSlotDto(
      slotId: json['slotId'] as String? ?? '',
      x: (json['coordX'] as num?)?.toDouble() ??
          (json['x'] as num?)?.toDouble() ??
          0.5,
      y: (json['coordY'] as num?)?.toDouble() ??
          (json['y'] as num?)?.toDouble() ??
          0.5,
      zIndex: (json['zIndex'] as num?)?.toInt() ??
          (json['slotIndex'] as num?)?.toInt() ??
          0,
      unlockTier: (json['tierRequired'] as num?)?.toInt() ??
          (json['unlockTier'] as num?)?.toInt() ??
          1,
      unlocked: json['unlocked'] as bool? ?? true,
      allowedCategories: rawCategories is List
          ? rawCategories.whereType<String>().toList()
          : const ['DECOR'],
      placement: placement,
      stableSlotKey: json['stableSlotKey'] as String?,
      regionCode: json['regionCode'] as String?,
      anchorX: (json['anchorX'] as num?)?.toDouble() ?? 0.5,
      anchorY: (json['anchorY'] as num?)?.toDouble() ?? 1.0,
      widthNorm: (json['widthNorm'] as num?)?.toDouble() ?? 0.10,
      heightNorm: (json['heightNorm'] as num?)?.toDouble() ?? 0.12,
    );
  }

  Map<String, dynamic> toJson() => {
    'slotId': slotId,
    'x': x,
    'y': y,
    'zIndex': zIndex,
    'unlockTier': unlockTier,
    'unlocked': unlocked,
    'allowedCategories': allowedCategories,
    'placement': placement?.toJson(),
    if (stableSlotKey != null) 'stableSlotKey': stableSlotKey,
    if (regionCode != null) 'regionCode': regionCode,
    'anchorX': anchorX,
    'anchorY': anchorY,
    'widthNorm': widthNorm,
    'heightNorm': heightNorm,
  };
}

/// Vùng đất trong layout, mở theo Tier (ISLAND-03/04).
@immutable
class IslandLayoutRegionDto {
  final String regionCode;
  final int unlockTier;
  final bool unlocked;
  final String? label;

  /// JSON string mô tả hình chữ nhật tương đối {x,y,width,height}.
  final String? boundsJson;

  const IslandLayoutRegionDto({
    required this.regionCode,
    required this.unlockTier,
    this.unlocked = false,
    this.label,
    this.boundsJson,
  });

  /// Giải mã hình chữ nhật chuẩn hóa [0,1] từ boundsJson.
  Rect? parseNormalizedBounds() {
    if (boundsJson == null || boundsJson!.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(boundsJson!);
      if (decoded is Map) {
        final x = (decoded['x'] as num?)?.toDouble();
        final y = (decoded['y'] as num?)?.toDouble();
        final w = (decoded['width'] as num?)?.toDouble();
        final h = (decoded['height'] as num?)?.toDouble();
        if (x != null && y != null && w != null && h != null && w > 0 && h > 0) {
          return Rect.fromLTWH(x, y, w, h);
        }
      }
    } catch (_) {}
    return null;
  }

  factory IslandLayoutRegionDto.fromJson(Map<String, dynamic> json) {
    return IslandLayoutRegionDto(
      regionCode: json['regionCode'] as String? ?? '',
      unlockTier: (json['unlockTier'] as num?)?.toInt() ?? 1,
      unlocked: json['unlocked'] as bool? ?? false,
      label: json['label'] as String?,
      boundsJson: json['boundsJson'] as String?,
    );
  }
}

/// Lớp scene của layout để Flutter render từng layer theo thứ tự (ISLAND-03/04).
@immutable
class IslandSceneLayerDto {
  final String layerKey;
  final String layerType;
  final int renderOrder;
  final String? assetRef;
  final String? visibilityRuleJson;

  const IslandSceneLayerDto({
    required this.layerKey,
    required this.layerType,
    this.renderOrder = 0,
    this.assetRef,
    this.visibilityRuleJson,
  });

  bool isVisibleForTier(int currentTier) {
    if (visibilityRuleJson == null || visibilityRuleJson!.trim().isEmpty) {
      return true;
    }
    try {
      final decoded = jsonDecode(visibilityRuleJson!);
      if (decoded is Map) {
        final minTier = (decoded['minTier'] as num?)?.toInt();
        final maxTier = (decoded['maxTier'] as num?)?.toInt();
        if (minTier != null && currentTier < minTier) return false;
        if (maxTier != null && currentTier > maxTier) return false;
      }
    } catch (_) {}
    return true;
  }

  factory IslandSceneLayerDto.fromJson(Map<String, dynamic> json) {
    return IslandSceneLayerDto(
      layerKey: json['layerKey'] as String? ?? '',
      layerType: json['layerType'] as String? ?? 'STATIC_IMAGE',
      renderOrder: (json['renderOrder'] as num?)?.toInt() ?? 0,
      assetRef: json['assetRef'] as String?,
      visibilityRuleJson: json['visibilityRuleJson'] as String?,
    );
  }
}

/// Tiến độ sự kiện hoàn thành để mở rộng đảo sang Tier tiếp theo.
@immutable
class IslandProgressDto {
  final int completedEvents;
  final int nextTierRequiredEvents;
  final bool canUpgrade;

  const IslandProgressDto({
    this.completedEvents = 0,
    this.nextTierRequiredEvents = 2,
    this.canUpgrade = false,
  });

  double get progressFraction {
    if (nextTierRequiredEvents <= 0) return 1.0;
    return (completedEvents / nextTierRequiredEvents).clamp(0.0, 1.0);
  }

  factory IslandProgressDto.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const IslandProgressDto();
    return IslandProgressDto(
      completedEvents: (json['completedEvents'] as num?)?.toInt() ?? 0,
      nextTierRequiredEvents:
          (json['nextTierRequiredEvents'] as num?)?.toInt() ?? 2,
      canUpgrade: json['canUpgrade'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'completedEvents': completedEvents,
    'nextTierRequiredEvents': nextTierRequiredEvents,
    'canUpgrade': canUpgrade,
  };
}

/// Mô hình tổng quan Đảo Di Sản từ GET /api/v1/me/island.
@immutable
class IslandDto {
  final int tier;
  final int maxTier;
  /// row_version từ backend (field: rowVersion). Dùng làm expectedRevision.
  final int rowVersion;
  /// EXP tích lũy của tài khoản (không tiêu hao).
  final int currentExp;
  /// Level tài khoản hiện tại (backend tính từ EXP).
  final int currentLevel;
  /// Level tối thiểu để nâng lên tier kế tiếp (null nếu đã max tier).
  final int? nextTierRequiredLevel;
  /// EXP tối thiểu tương ứng với nextTierRequiredLevel (null nếu đã max tier).
  final int? nextTierRequiredExp;
  /// Tổng số slot khi nâng lên tier kế tiếp (0 nếu đã max tier).
  final int nextTierSlotCount;
  /// Backend xác nhận user có quyền nâng cấp không.
  final bool canUpgrade;
  /// Số sự kiện hoàn thành (chỉ còn để tương thích, không dùng xét eligibility).
  final int eventsCompleted;
  final List<IslandSlotDto> slots;

  // Kept for backwards compat with mock / old screens that still read progress.
  // Do NOT use progress.canUpgrade for eligibility — use canUpgrade directly.
  final IslandProgressDto progress;

  // Layout metadata (ISLAND-03) — data-driven canvas; fallback to 960x720.
  /// layout_key (e.g. 'heritage-village'). Null nếu backend cũ không trả.
  final String? layoutCode;
  /// UUID của layout version. Null nếu backend cũ không trả.
  final String? layoutVersionId;
  /// Số version layout. 0 nếu không có.
  final int layoutVersionNumber;
  /// Chiều rộng canvas ảo (px logic). Fallback 960.
  final double canvasWidth;
  /// Chiều cao canvas ảo (px logic). Fallback 720.
  final double canvasHeight;
  /// Theme key cho renderer. Null nếu backend chưa set.
  final String? themeKey;
  /// Danh sách vùng đất mở theo Tier.
  final List<IslandLayoutRegionDto> regions;
  /// Danh sách scene layers theo render_order.
  final List<IslandSceneLayerDto> sceneLayers;

  const IslandDto({
    this.tier = 1,
    this.maxTier = 3,
    this.rowVersion = 0,
    this.currentExp = 0,
    this.currentLevel = 1,
    this.nextTierRequiredLevel,
    this.nextTierRequiredExp,
    this.nextTierSlotCount = 0,
    this.canUpgrade = false,
    this.eventsCompleted = 0,
    this.slots = const [],
    this.progress = const IslandProgressDto(),
    this.layoutCode,
    this.layoutVersionId,
    this.layoutVersionNumber = 0,
    this.canvasWidth = 960.0,
    this.canvasHeight = 720.0,
    this.themeKey,
    this.regions = const [],
    this.sceneLayers = const [],
  });

  bool get isMaxTier => tier >= maxTier;

  /// Tên quy mô đảo theo Tier (Đảo nhỏ / Đảo vừa / Đảo lớn).
  String get tierScaleLabel {
    switch (tier) {
      case 1:
        return 'Đảo nhỏ';
      case 2:
        return 'Đảo vừa';
      case 3:
        return 'Đảo lớn';
      default:
        return 'Đảo cấp $tier';
    }
  }

  /// Số slot đã mở khóa hiện tại.
  int get unlockedSlotCount =>
      slots.where((s) => s.unlocked || s.unlockTier <= tier).length;

  /// Alias kept for providers that still reference island.revision.
  int get revision => rowVersion;

  IslandDto copyWith({
    int? tier,
    int? maxTier,
    int? rowVersion,
    int? currentExp,
    int? currentLevel,
    int? nextTierRequiredLevel,
    int? nextTierRequiredExp,
    int? nextTierSlotCount,
    bool? canUpgrade,
    int? eventsCompleted,
    List<IslandSlotDto>? slots,
    IslandProgressDto? progress,
    String? layoutCode,
    String? layoutVersionId,
    int? layoutVersionNumber,
    double? canvasWidth,
    double? canvasHeight,
    String? themeKey,
    List<IslandLayoutRegionDto>? regions,
    List<IslandSceneLayerDto>? sceneLayers,
  }) {
    return IslandDto(
      tier: tier ?? this.tier,
      maxTier: maxTier ?? this.maxTier,
      rowVersion: rowVersion ?? this.rowVersion,
      currentExp: currentExp ?? this.currentExp,
      currentLevel: currentLevel ?? this.currentLevel,
      nextTierRequiredLevel: nextTierRequiredLevel ?? this.nextTierRequiredLevel,
      nextTierRequiredExp: nextTierRequiredExp ?? this.nextTierRequiredExp,
      nextTierSlotCount: nextTierSlotCount ?? this.nextTierSlotCount,
      canUpgrade: canUpgrade ?? this.canUpgrade,
      eventsCompleted: eventsCompleted ?? this.eventsCompleted,
      slots: slots ?? this.slots,
      progress: progress ?? this.progress,
      layoutCode: layoutCode ?? this.layoutCode,
      layoutVersionId: layoutVersionId ?? this.layoutVersionId,
      layoutVersionNumber: layoutVersionNumber ?? this.layoutVersionNumber,
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      themeKey: themeKey ?? this.themeKey,
      regions: regions ?? this.regions,
      sceneLayers: sceneLayers ?? this.sceneLayers,
    );
  }

  factory IslandDto.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'];
    final rawRegions = json['regions'];
    final rawLayers = json['sceneLayers'];
    final nextReqLevel = (json['nextTierRequiredLevel'] as num?)?.toInt();
    final nextReqExp = (json['nextTierRequiredExp'] as num?)?.toInt();
    final eventsCompleted = (json['eventsCompleted'] as num?)?.toInt() ?? 0;
    final canUpgrade = json['canUpgrade'] as bool? ?? false;
    return IslandDto(
      tier: (json['tier'] as num?)?.toInt() ?? 1,
      maxTier: (json['maxTier'] as num?)?.toInt() ?? 3,
      // Backend field is rowVersion (ISLAND-02); fall back to revision for mock
      rowVersion: (json['rowVersion'] as num?)?.toInt() ??
          (json['revision'] as num?)?.toInt() ??
          0,
      currentExp: (json['currentExp'] as num?)?.toInt() ?? 0,
      currentLevel: (json['currentLevel'] as num?)?.toInt() ?? 1,
      nextTierRequiredLevel: nextReqLevel,
      nextTierRequiredExp: nextReqExp,
      nextTierSlotCount: (json['nextTierSlotCount'] as num?)?.toInt() ?? 0,
      canUpgrade: canUpgrade,
      eventsCompleted: eventsCompleted,
      slots: rawSlots is List
          ? rawSlots
                .whereType<Map>()
                .map((e) => IslandSlotDto.fromJson(e.cast<String, dynamic>()))
                .toList()
          : const [],
      // Keep progress populated for any code still reading it
      progress: IslandProgressDto(
        completedEvents: eventsCompleted,
        nextTierRequiredEvents:
            (json['nextTierRequiredEvents'] as num?)?.toInt() ?? 0,
        canUpgrade: canUpgrade,
      ),
      // Layout metadata (ISLAND-03) — null-safe, fallback to defaults
      layoutCode: json['layoutCode'] as String?,
      layoutVersionId: json['layoutVersionId'] as String?,
      layoutVersionNumber:
          (json['layoutVersionNumber'] as num?)?.toInt() ?? 0,
      canvasWidth: (json['canvasWidth'] as num?)?.toDouble() ?? 960.0,
      canvasHeight: (json['canvasHeight'] as num?)?.toDouble() ?? 720.0,
      themeKey: json['themeKey'] as String?,
      regions: rawRegions is List
          ? rawRegions
                .whereType<Map>()
                .map((e) => IslandLayoutRegionDto.fromJson(
                      e.cast<String, dynamic>()))
                .toList()
          : const [],
      sceneLayers: rawLayers is List
          ? rawLayers
                .whereType<Map>()
                .map((e) => IslandSceneLayerDto.fromJson(
                      e.cast<String, dynamic>()))
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'tier': tier,
    'maxTier': maxTier,
    'rowVersion': rowVersion,
    'currentExp': currentExp,
    'currentLevel': currentLevel,
    'nextTierRequiredLevel': nextTierRequiredLevel,
    'nextTierRequiredExp': nextTierRequiredExp,
    'canUpgrade': canUpgrade,
    'eventsCompleted': eventsCompleted,
    'slots': slots.map((s) => s.toJson()).toList(),
    if (layoutCode != null) 'layoutCode': layoutCode,
    if (layoutVersionId != null) 'layoutVersionId': layoutVersionId,
    'layoutVersionNumber': layoutVersionNumber,
    'canvasWidth': canvasWidth,
    'canvasHeight': canvasHeight,
    if (themeKey != null) 'themeKey': themeKey,
  };
}

/// Một mặt hàng trang trí trong cửa hàng Điểm Sử Ký (GET /api/v1/shop/items).
@immutable
class ShopItemDto {
  final String itemId;
  final String code;
  final String name;
  final String? description;
  final String category;
  /// Giá tính bằng Điểm Sử Ký. null = chưa mở bán (purchasable=false).
  final int? pricePoints;
  /// Backend xác nhận item có thể mua không (active=true và price != null).
  final bool purchasable;
  final String? renderKey;
  final String? assetId;
  final bool placeable;
  /// Phản ánh trạng thái sở hữu từ inventory (mock hoặc enriched client-side).
  /// Backend ShopItemResponse không trả field này — mặc định false từ listing.
  final bool owned;
  /// True chỉ khi đã đối chiếu thành công với `/me/inventory`.
  /// Nếu tải inventory thất bại, `ownershipVerified = false` để khóa nút MUA.
  final bool ownershipVerified;

  const ShopItemDto({
    required this.itemId,
    required this.code,
    required this.name,
    this.description,
    this.category = 'DECOR',
    this.pricePoints,
    this.purchasable = false,
    this.renderKey,
    this.assetId,
    this.placeable = true,
    this.owned = false,
    this.ownershipVerified = true,
  });

  /// Tiện ích: giá để hiển thị (0 nếu chưa mở bán).
  int get price => pricePoints ?? 0;

  /// Vật phẩm chỉ được phép mua khi purchasable = true và có giá > 0.
  bool get isForSale => purchasable && pricePoints != null && pricePoints! > 0;

  String? get assetPath => resolveIslandAsset(renderKey, code, assetId);

  ShopItemDto copyWith({bool? owned, bool? ownershipVerified}) {
    return ShopItemDto(
      itemId: itemId,
      code: code,
      name: name,
      description: description,
      category: category,
      pricePoints: pricePoints,
      purchasable: purchasable,
      renderKey: renderKey,
      assetId: assetId,
      placeable: placeable,
      owned: owned ?? this.owned,
      ownershipVerified: ownershipVerified ?? this.ownershipVerified,
    );
  }

  factory ShopItemDto.fromJson(Map<String, dynamic> json) {
    return ShopItemDto(
      itemId: json['itemId'] as String? ?? json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'DECOR',
      // Backend: pricePoints (Long, nullable). Legacy mock may use price.
      pricePoints: (json['pricePoints'] as num?)?.toInt() ??
          (json['price'] as num?)?.toInt(),
      purchasable: json['purchasable'] as bool? ?? false,
      renderKey: json['renderKey'] as String?,
      assetId: json['assetId'] as String?,
      placeable: json['placeable'] as bool? ?? true,
      // owned không có trong backend listing — default false.
      owned: json['owned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'code': code,
    'name': name,
    'description': description,
    'category': category,
    'pricePoints': pricePoints,
    'purchasable': purchasable,
    'renderKey': renderKey,
    'assetId': assetId,
    'placeable': placeable,
    'owned': owned,
  };
}

/// Số dư ví người học (GET /api/v1/me/wallet).
@immutable
class WalletDto {
  final int historyPoints;
  final int exp;

  const WalletDto({this.historyPoints = 0, this.exp = 0});

  factory WalletDto.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WalletDto();
    return WalletDto(
      historyPoints:
          (json['historyPoints'] as num?)?.toInt() ??
          (json['points'] as num?)?.toInt() ??
          (json['balance'] as num?)?.toInt() ??
          0,
      exp: (json['exp'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'historyPoints': historyPoints, 'exp': exp};
}
