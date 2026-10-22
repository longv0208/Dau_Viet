/// DTO thưởng + vật phẩm (TASK-0023) — khớp các response record phía
/// backend: RewardSummaryResponse / RewardTransactionResponse /
/// InventoryItemResponse / CatalogItemResponse.
library;

/// GET /api/v1/me/rewards/summary — tổng quan điểm của learner.
class RewardSummaryDto {
  final int exp;
  final int historyPoints;
  final int lessonsCompleted;
  final int itemsOwned;

  const RewardSummaryDto({
    this.exp = 0,
    this.historyPoints = 0,
    this.lessonsCompleted = 0,
    this.itemsOwned = 0,
  });

  factory RewardSummaryDto.fromJson(Map<String, dynamic>? json) =>
      RewardSummaryDto(
        exp: (json?['exp'] as num?)?.toInt() ?? 0,
        historyPoints: (json?['historyPoints'] as num?)?.toInt() ?? 0,
        lessonsCompleted: (json?['lessonsCompleted'] as num?)?.toInt() ?? 0,
        itemsOwned: (json?['itemsOwned'] as num?)?.toInt() ?? 0,
      );

  static const empty = RewardSummaryDto();
}

/// Một bút toán thưởng — EXP hoặc HISTORY_POINTS đã được server ghi vào
/// ledger trong cùng transaction complete(). Client chỉ hiển thị, KHÔNG
/// gọi thêm endpoint nào để "nhận" thưởng.
class RewardTransactionDto {
  final String id;
  final String rewardType;
  final int amount;
  final String? reason;
  final String? lessonId;
  final String? createdAt;

  const RewardTransactionDto({
    required this.id,
    required this.rewardType,
    required this.amount,
    this.reason,
    this.lessonId,
    this.createdAt,
  });

  factory RewardTransactionDto.fromJson(Map<String, dynamic> json) =>
      RewardTransactionDto(
        id: json['id'] as String? ?? '',
        rewardType: json['rewardType'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String?,
        lessonId: json['lessonId'] as String?,
        createdAt: json['createdAt'] as String?,
      );
}

/// Một vật phẩm learner đã sở hữu (GET /me/inventory) — hoặc phần tử của
/// `itemsUnlocked` trong LessonResultResponse (cùng shape).
class InventoryItemDto {
  final String itemId;
  final String code;
  final String name;
  final String? description;
  final String category;
  final String itemType;
  final String rarity;
  final String? assetId;
  final String? acquiredAt;
  final String? acquisitionSource;
  final String? sourceLessonId;

  const InventoryItemDto({
    required this.itemId,
    required this.code,
    required this.name,
    this.description,
    required this.category,
    required this.itemType,
    required this.rarity,
    this.assetId,
    this.acquiredAt,
    this.acquisitionSource,
    this.sourceLessonId,
  });

  factory InventoryItemDto.fromJson(Map<String, dynamic> json) =>
      InventoryItemDto(
        itemId: json['itemId'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        category: json['category'] as String? ?? '',
        itemType: json['itemType'] as String? ?? '',
        rarity: json['rarity'] as String? ?? 'COMMON',
        assetId: json['assetId'] as String?,
        acquiredAt: json['acquiredAt'] as String?,
        acquisitionSource: json['acquisitionSource'] as String?,
        sourceLessonId: json['sourceLessonId'] as String?,
      );
}

/// Điều kiện mở khóa kèm tiến độ hiện tại — `current` do server tính sẵn
/// (số evidence đã sưu tầm / số bài đã hoàn thành) nên client render trực
/// tiếp, không tự đếm.
class ItemRequirementDto {
  final String type;
  final String? lessonId;
  final String? lessonTitle;
  final int? threshold;
  final int? current;

  const ItemRequirementDto({
    required this.type,
    this.lessonId,
    this.lessonTitle,
    this.threshold,
    this.current,
  });

  factory ItemRequirementDto.fromJson(Map<String, dynamic> json) =>
      ItemRequirementDto(
        type: json['type'] as String? ?? '',
        lessonId: json['lessonId'] as String?,
        lessonTitle: json['lessonTitle'] as String?,
        threshold: (json['threshold'] as num?)?.toInt(),
        current: (json['current'] as num?)?.toInt(),
      );

  /// Câu mô tả điều kiện ngắn gọn cho UI — không bịa nội dung ngoài dữ
  /// liệu rule server trả về.
  String describe() {
    switch (type) {
      case 'LESSON_COMPLETED':
        return 'Hoàn thành bài học "${lessonTitle ?? 'được chỉ định'}"';
      case 'COLLECTION_COUNT':
        return 'Sưu tầm đủ $threshold bằng chứng (đã có ${current ?? 0})';
      case 'LESSON_COUNT':
        return 'Hoàn thành đủ $threshold bài học (đã xong ${current ?? 0})';
      default:
        return 'Điều kiện mở khóa';
    }
  }

  /// Tiến độ 0..1 để vẽ thanh nhỏ — null khi rule không phải loại đếm.
  double? get progressFraction {
    if (threshold == null || threshold! <= 0) return null;
    final c = (current ?? 0).clamp(0, threshold!);
    return c / threshold!;
  }
}

/// Một mục catalog (GET /me/inventory/catalog): metadata + owned +
/// requirement + progress — một call render đủ lưới đã sở hữu/chưa mở.
class CatalogItemDto {
  final String itemId;
  final String code;
  final String name;
  final String? description;
  final String category;
  final String itemType;
  final String rarity;
  final String? assetId;
  final bool owned;
  final String? acquiredAt;
  final ItemRequirementDto? requirement;
  final String? sourceNote;

  const CatalogItemDto({
    required this.itemId,
    required this.code,
    required this.name,
    this.description,
    required this.category,
    required this.itemType,
    required this.rarity,
    this.assetId,
    this.owned = false,
    this.acquiredAt,
    this.requirement,
    this.sourceNote,
  });

  factory CatalogItemDto.fromJson(Map<String, dynamic> json) => CatalogItemDto(
    itemId: json['itemId'] as String? ?? '',
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    category: json['category'] as String? ?? '',
    itemType: json['itemType'] as String? ?? '',
    rarity: json['rarity'] as String? ?? 'COMMON',
    assetId: json['assetId'] as String?,
    owned: json['owned'] as bool? ?? false,
    acquiredAt: json['acquiredAt'] as String?,
    requirement: json['requirement'] is Map
        ? ItemRequirementDto.fromJson(
            (json['requirement'] as Map).cast<String, dynamic>(),
          )
        : null,
    sourceNote: json['sourceMetadata'] is Map
        ? (json['sourceMetadata'] as Map)['note'] as String?
        : null,
  );
}

/// PageResponse backend envelope cho GET /me/rewards/transactions.
class RewardTransactionPageDto {
  final List<RewardTransactionDto> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  const RewardTransactionPageDto({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  bool get hasMore => page + 1 < totalPages;

  factory RewardTransactionPageDto.fromJson(Map<String, dynamic> json) {
    final raw = json['content'] ?? json['items'];
    return RewardTransactionPageDto(
      content: raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (e) =>
                      RewardTransactionDto.fromJson(e.cast<String, dynamic>()),
                )
                .toList()
          : const [],
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}
