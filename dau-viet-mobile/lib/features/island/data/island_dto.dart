import 'package:flutter/foundation.dart';

/// Trả về đường dẫn asset cục bộ dựa vào renderKey, code hoặc assetId.
String resolveIslandAsset(String? renderKey, String? code, [String? assetId]) {
  final key = (renderKey ?? code ?? assetId ?? '').toLowerCase().trim();
  if (key.contains('nha_tranh') ||
      key.contains('nhatranh') ||
      key.contains('nha')) {
    return 'assets/items/decor_nha_tranh.png';
  }
  if (key.contains('cau_kieu') ||
      key.contains('caukieu') ||
      key.contains('cau') ||
      key.contains('thuyen')) {
    return 'assets/items/decor_cau_kieu.png';
  }
  if (key.contains('ho_sen') ||
      key.contains('hosen') ||
      key.contains('sen') ||
      key.contains('gieng')) {
    return 'assets/items/decor_ho_sen.png';
  }
  if (key.contains('cay_da') ||
      key.contains('cayda') ||
      key.contains('cay') ||
      key.contains('truc')) {
    return 'assets/items/decor_cay_da.png';
  }
  return 'assets/items/decor_nha_tranh.png';
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

  String get assetPath => resolveIslandAsset(renderKey, code, assetId);

  factory IslandPlacementDto.fromJson(Map<String, dynamic> json) {
    return IslandPlacementDto(
      itemId: json['itemId'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      renderKey: json['renderKey'] as String?,
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

  const IslandSlotDto({
    required this.slotId,
    required this.x,
    required this.y,
    this.zIndex = 0,
    this.unlockTier = 1,
    this.unlocked = true,
    this.allowedCategories = const ['DECOR'],
    this.placement,
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
    );
  }

  factory IslandSlotDto.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['allowedCategories'];
    // Backend SlotView fields: slotId, slotIndex, tierRequired, unlocked,
    // coordX, coordY, placedItemId, placedItemCode, placedRenderKey, placedAt.
    // Fall-back to legacy field names so MockIslandRepository still works.
    final placedItemId = json['placedItemId'] as String?;
    final placedItemCode = json['placedItemCode'] as String?;
    final placedRenderKey = json['placedRenderKey'] as String?;
    // Build placement from flat backend fields, or from legacy nested map
    IslandPlacementDto? placement;
    if (placedItemId != null) {
      placement = IslandPlacementDto(
        itemId: placedItemId,
        code: placedItemCode ?? '',
        name: placedItemCode ?? '',
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
      zIndex: (json['slotIndex'] as num?)?.toInt() ??
          (json['zIndex'] as num?)?.toInt() ??
          0,
      unlockTier: (json['tierRequired'] as num?)?.toInt() ??
          (json['unlockTier'] as num?)?.toInt() ??
          1,
      unlocked: json['unlocked'] as bool? ?? true,
      allowedCategories: rawCategories is List
          ? rawCategories.whereType<String>().toList()
          : const ['DECOR'],
      placement: placement,
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
  };
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
  /// Backend xác nhận user có quyền nâng cấp không.
  final bool canUpgrade;
  /// Số sự kiện hoàn thành (chỉ còn để tương thích, không dùng xét eligibility).
  final int eventsCompleted;
  final List<IslandSlotDto> slots;

  // Kept for backwards compat with mock / old screens that still read progress.
  // Do NOT use progress.canUpgrade for eligibility — use canUpgrade directly.
  final IslandProgressDto progress;

  const IslandDto({
    this.tier = 1,
    this.maxTier = 3,
    this.rowVersion = 0,
    this.currentExp = 0,
    this.currentLevel = 1,
    this.nextTierRequiredLevel,
    this.nextTierRequiredExp,
    this.canUpgrade = false,
    this.eventsCompleted = 0,
    this.slots = const [],
    this.progress = const IslandProgressDto(),
  });

  bool get isMaxTier => tier >= maxTier;

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
    bool? canUpgrade,
    int? eventsCompleted,
    List<IslandSlotDto>? slots,
    IslandProgressDto? progress,
  }) {
    return IslandDto(
      tier: tier ?? this.tier,
      maxTier: maxTier ?? this.maxTier,
      rowVersion: rowVersion ?? this.rowVersion,
      currentExp: currentExp ?? this.currentExp,
      currentLevel: currentLevel ?? this.currentLevel,
      nextTierRequiredLevel: nextTierRequiredLevel ?? this.nextTierRequiredLevel,
      nextTierRequiredExp: nextTierRequiredExp ?? this.nextTierRequiredExp,
      canUpgrade: canUpgrade ?? this.canUpgrade,
      eventsCompleted: eventsCompleted ?? this.eventsCompleted,
      slots: slots ?? this.slots,
      progress: progress ?? this.progress,
    );
  }

  factory IslandDto.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'];
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
  });

  /// Tiện ích: giá để hiển thị (0 nếu chưa mở bán).
  int get price => pricePoints ?? 0;

  String get assetPath => resolveIslandAsset(renderKey, code, assetId);

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
