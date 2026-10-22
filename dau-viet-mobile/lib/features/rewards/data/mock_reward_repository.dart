import 'reward_dtos.dart';
import 'reward_repository.dart';

/// Dữ liệu demo rõ ràng cho `USE_MOCK=true` — thưởng + catalog mẫu gắn
/// content pack Bạch Đằng. Không phải fallback: chỉ dùng khi build chạy
/// chế độ demo. Vật phẩm luôn là mô hình/phiên bản số/huy hiệu — không
/// gọi là cổ vật thật.
class MockRewardRepository implements RewardRepository {
  static const RewardSummaryDto _summary = RewardSummaryDto(
    exp: 200,
    historyPoints: 100,
    lessonsCompleted: 2,
    itemsOwned: 1,
  );

  static const List<RewardTransactionDto> _transactions = [
    RewardTransactionDto(
      id: 'demo-tx-1',
      rewardType: 'EXP',
      amount: 100,
      reason: 'Hoàn thành lần đầu bài học Cọc ngầm Bạch Đằng',
      lessonId: '00000000-0000-0000-0000-000000000201',
      createdAt: '2025-10-21T09:00:00Z',
    ),
    RewardTransactionDto(
      id: 'demo-tx-2',
      rewardType: 'HISTORY_POINTS',
      amount: 50,
      reason: 'Hoàn thành lần đầu bài học Cọc ngầm Bạch Đằng',
      lessonId: '00000000-0000-0000-0000-000000000201',
      createdAt: '2025-10-21T09:00:00Z',
    ),
  ];

  static const List<CatalogItemDto> _catalog = [
    CatalogItemDto(
      itemId: 'demo-item-1',
      code: 'HUY_HIEU_HAI_BA_TRUNG',
      name: 'Huy hiệu kỷ niệm Hai Bà Trưng',
      description:
          'Huy hiệu kỷ niệm khởi nghĩa Hai Bà Trưng năm 40 — tinh thần độc lập đầu tiên sau thời kỳ Bắc thuộc.',
      category: 'HUY_HIEU',
      itemType: 'COMMEMORATIVE_BADGE',
      rarity: 'COMMON',
      owned: true,
      acquiredAt: '2025-10-21T09:05:00Z',
      requirement: ItemRequirementDto(
        type: 'COLLECTION_COUNT',
        threshold: 3,
        current: 3,
      ),
      sourceNote: 'Huy hiệu kỷ niệm, không phải hiện vật',
    ),
    CatalogItemDto(
      itemId: 'demo-item-2',
      code: 'PHIEN_BAN_SO_COC_BACH_DANG',
      name: 'Phiên bản số cọc ngầm Bạch Đằng',
      description:
          'Phiên bản số tái hiện cọc ngầm trận Bạch Đằng 938 — di chỉ cọc gỗ được nghiên cứu niên đại C-14.',
      category: 'PHIEN_BAN_SO',
      itemType: 'DIGITAL_EDITION',
      rarity: 'UNCOMMON',
      requirement: ItemRequirementDto(
        type: 'COLLECTION_COUNT',
        threshold: 5,
        current: 3,
      ),
      sourceNote: 'Tái hiện số cho mục đích giáo dục',
    ),
    CatalogItemDto(
      itemId: 'demo-item-3',
      code: 'MO_HINH_TRONG_DONG_DONG_SON',
      name: 'Mô hình trống đồng Đông Sơn',
      description:
          'Mô hình thu nhỏ của trống đồng Đông Sơn — biểu tượng nền văn hóa Đông Sơn.',
      category: 'MO_HINH',
      itemType: 'HISTORICAL_REPLICA',
      rarity: 'RARE',
      requirement: ItemRequirementDto(
        type: 'COLLECTION_COUNT',
        threshold: 12,
        current: 3,
      ),
      sourceNote: 'Mô hình phục vụ học tập, không phải hiện vật thật',
    ),
  ];

  @override
  Future<RewardSummaryDto> summary() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _summary;
  }

  @override
  Future<RewardTransactionPageDto> transactions({
    int page = 0,
    int size = 20,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return const RewardTransactionPageDto(
      content: _transactions,
      page: 0,
      size: 20,
      totalElements: 2,
      totalPages: 1,
    );
  }

  @override
  Future<List<InventoryItemDto>> inventory() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return const [
      InventoryItemDto(
        itemId: 'demo-item-1',
        code: 'HUY_HIEU_HAI_BA_TRUNG',
        name: 'Huy hiệu kỷ niệm Hai Bà Trưng',
        description:
            'Huy hiệu kỷ niệm khởi nghĩa Hai Bà Trưng năm 40 — tinh thần độc lập đầu tiên sau thời kỳ Bắc thuộc.',
        category: 'HUY_HIEU',
        itemType: 'COMMEMORATIVE_BADGE',
        rarity: 'COMMON',
        acquiredAt: '2025-10-21T09:05:00Z',
        acquisitionSource: 'COLLECTION_COUNT',
      ),
    ];
  }

  @override
  Future<List<CatalogItemDto>> catalog() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _catalog;
  }
}
