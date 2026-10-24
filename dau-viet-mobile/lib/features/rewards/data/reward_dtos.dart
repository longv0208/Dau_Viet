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
/// `itemsUnlocked` trong LessonResultResponse (cùng shape). GAME-05: thêm
/// provenance (rule + version, event nguồn) — additive, client cũ vẫn đọc
/// được khi server chưa trả field mới.
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
  final String? unlockRuleId;
  final int? unlockRuleVersion;
  final String? sourceEventId;

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
    this.unlockRuleId,
    this.unlockRuleVersion,
    this.sourceEventId,
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
        unlockRuleId: json['unlockRuleId'] as String?,
        unlockRuleVersion: (json['unlockRuleVersion'] as num?)?.toInt(),
        sourceEventId: json['sourceEventId'] as String?,
      );
}

/// Một node điều kiện mở khóa (GAME-05): hoặc leaf (type + current/required
/// server đã tính) hoặc operator (ALL|ANY + children). UI render TỪNG DÒNG
/// điều kiện — không gộp thành một progress bar tổng gây hiểu nhầm khi
/// rule nhiều nhánh.
class ItemRequirementDto {
  /// 'ALL' | 'ANY' khi là operator; null ở leaf.
  final String? operator;
  final String type;
  final String? eventId;
  final String? lessonId;
  final String? lessonTitle;
  final List<String>? evidenceIds;
  final int? threshold;
  final int? current;
  final int? required;
  final bool satisfied;

  /// SATISFIED | PENDING | UNSUPPORTED | UNCONFIGURED — UNSUPPORTED không
  /// bao giờ đạt (ví dụ LEVEL_AT_LEAST chờ GAME-07); UNCONFIGURED = rule
  /// đang chờ admin cập nhật (FIX-1 backend chặn grant + báo trạng thái
  /// này) — không hiển thị progress bar hay "đã đủ điều kiện" giả.
  final String status;
  final String? description;
  final List<ItemRequirementDto> conditions;

  const ItemRequirementDto({
    this.operator,
    this.type = '',
    this.eventId,
    this.lessonId,
    this.lessonTitle,
    this.evidenceIds,
    this.threshold,
    this.current,
    this.required,
    this.satisfied = false,
    this.status = 'PENDING',
    this.description,
    this.conditions = const [],
  });

  bool get isOperator => operator == 'ALL' || operator == 'ANY';
  bool get isUnsupported => status == 'UNSUPPORTED';

  /// FIX-1: rule bị audit-flag needs-mapping — backend chặn grant và báo
  /// status này để UI hiển thị trung lập, KHÔNG progress bar, KHÔNG
  /// "đã đủ" giả. Biến mất ngay khi admin publish rule v2 hợp lệ.
  bool get isUnconfigured => status == 'UNCONFIGURED';

  factory ItemRequirementDto.fromJson(Map<String, dynamic> json) {
    final rawConditions = json['conditions'];
    return ItemRequirementDto(
      operator: json['operator'] as String?,
      type: json['type'] as String? ?? '',
      eventId: json['eventId'] as String?,
      lessonId: json['lessonId'] as String?,
      lessonTitle: json['lessonTitle'] as String?,
      evidenceIds: json['evidenceIds'] is List
          ? (json['evidenceIds'] as List).whereType<String>().toList(
              growable: false,
            )
          : null,
      threshold: (json['threshold'] as num?)?.toInt(),
      current: (json['current'] as num?)?.toInt(),
      required: (json['required'] as num?)?.toInt(),
      satisfied: json['satisfied'] as bool? ?? false,
      status: json['status'] as String? ?? 'PENDING',
      description: json['description'] as String?,
      conditions: rawConditions is List
          ? rawConditions
                .whereType<Map>()
                .map(
                  (e) => ItemRequirementDto.fromJson(e.cast<String, dynamic>()),
                )
                .toList(growable: false)
          : const [],
    );
  }

  /// Tiêu đề nhóm cho operator — văn bản server-authored lấy từ
  /// `description`, fallback cố định theo contract §UI.
  String operatorHeading() {
    if (description != null && description!.isNotEmpty) return description!;
    return operator == 'ALL'
        ? 'Hoàn thành tất cả điều kiện sau'
        : 'Hoàn thành một trong các điều kiện sau';
  }

  /// Câu mô tả leaf ngắn gọn — ưu tiên `description` server trả về; chỉ
  /// fallback suy diễn khi server không gửi (dữ liệu cũ), vẫn không bịa
  /// nội dung ngoài type + current/required.
  String describe() {
    if (description != null && description!.isNotEmpty) {
      final progress = _progressSuffix();
      return progress == null ? description! : '$description $progress';
    }
    switch (type) {
      case 'LESSON_COMPLETED':
        return 'Hoàn thành bài học "${lessonTitle ?? 'được chỉ định'}"';
      case 'COLLECTION_COUNT':
        return 'Sưu tầm đủ ${required ?? threshold} bằng chứng${_progressSuffix() ?? ''}';
      case 'LESSON_COUNT':
        return 'Hoàn thành đủ ${required ?? threshold} bài học${_progressSuffix() ?? ''}';
      case 'EVENT_EVIDENCE_COUNT':
        return 'Sưu tầm đủ ${required ?? threshold} bằng chứng của sự kiện${_progressSuffix() ?? ''}';
      case 'TOTAL_EVENTS_COMPLETED':
        return 'Hoàn thành đủ ${required ?? threshold} sự kiện${_progressSuffix() ?? ''}';
      case 'EVENT_COMPLETED':
        return 'Hoàn thành sự kiện yêu cầu';
      case 'EVENT_MASTERED':
        return 'Đạt thành thạo sự kiện yêu cầu';
      case 'LEVEL_AT_LEAST':
        return 'Điều kiện cấp độ chưa được hỗ trợ';
      default:
        return 'Điều kiện mở khóa';
    }
  }

  String? _progressSuffix() {
    final req = required ?? threshold;
    if (req == null) return null;
    return '(${current ?? 0}/$req)';
  }

  /// Tiến độ 0..1 của MỘT leaf — null khi leaf boolean hoặc operator
  /// (operator không vẽ bar tổng hợp).
  double? get progressFraction {
    if (isOperator) return null;
    final req = required ?? threshold;
    if (req == null || req <= 0) return null;
    final c = (current ?? 0).clamp(0, req);
    return c / req;
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
