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
    return IslandSlotDto(
      slotId: json['slotId'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0.5,
      y: (json['y'] as num?)?.toDouble() ?? 0.5,
      zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
      unlockTier: (json['unlockTier'] as num?)?.toInt() ?? 1,
      unlocked: json['unlocked'] as bool? ?? true,
      allowedCategories: rawCategories is List
          ? rawCategories.whereType<String>().toList()
          : const ['DECOR'],
      placement: json['placement'] is Map
          ? IslandPlacementDto.fromJson(
              (json['placement'] as Map).cast<String, dynamic>(),
            )
          : null,
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
  final int revision;
  final IslandProgressDto progress;
  final List<IslandSlotDto> slots;

  const IslandDto({
    this.tier = 1,
    this.maxTier = 3,
    this.revision = 0,
    this.progress = const IslandProgressDto(),
    this.slots = const [],
  });

  bool get isMaxTier => tier >= maxTier;

  IslandDto copyWith({
    int? tier,
    int? maxTier,
    int? revision,
    IslandProgressDto? progress,
    List<IslandSlotDto>? slots,
  }) {
    return IslandDto(
      tier: tier ?? this.tier,
      maxTier: maxTier ?? this.maxTier,
      revision: revision ?? this.revision,
      progress: progress ?? this.progress,
      slots: slots ?? this.slots,
    );
  }

  factory IslandDto.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'];
    return IslandDto(
      tier: (json['tier'] as num?)?.toInt() ?? 1,
      maxTier: (json['maxTier'] as num?)?.toInt() ?? 3,
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      progress: IslandProgressDto.fromJson(
        json['progress'] is Map
            ? (json['progress'] as Map).cast<String, dynamic>()
            : null,
      ),
      slots: rawSlots is List
          ? rawSlots
                .whereType<Map>()
                .map((e) => IslandSlotDto.fromJson(e.cast<String, dynamic>()))
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'tier': tier,
    'maxTier': maxTier,
    'revision': revision,
    'progress': progress.toJson(),
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
  final int price;
  final String currency;
  final int? requiredLevel;
  final bool owned;
  final String? renderKey;
  final String? assetId;
  final bool placeable;

  const ShopItemDto({
    required this.itemId,
    required this.code,
    required this.name,
    this.description,
    this.category = 'DECOR',
    required this.price,
    this.currency = 'HISTORY_POINTS',
    this.requiredLevel,
    this.owned = false,
    this.renderKey,
    this.assetId,
    this.placeable = true,
  });

  String get assetPath => resolveIslandAsset(renderKey, code, assetId);

  factory ShopItemDto.fromJson(Map<String, dynamic> json) {
    return ShopItemDto(
      itemId: json['itemId'] as String? ?? json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'DECOR',
      price: (json['price'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'HISTORY_POINTS',
      requiredLevel: (json['requiredLevel'] as num?)?.toInt(),
      owned: json['owned'] as bool? ?? false,
      renderKey: json['renderKey'] as String?,
      assetId: json['assetId'] as String?,
      placeable: json['placeable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'code': code,
    'name': name,
    'description': description,
    'category': category,
    'price': price,
    'currency': currency,
    'requiredLevel': requiredLevel,
    'owned': owned,
    'renderKey': renderKey,
    'assetId': assetId,
    'placeable': placeable,
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
