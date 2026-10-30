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
    CatalogItemDto(
      itemId: 'item_dinh_lang',
      code: 'DECOR_DINH_LANG',
      name: 'Đình Làng Mái Đao',
      description: 'Ngôi đình cổ với mái đao cong vút trang trí Đảo Di Sản.',
      category: 'DECOR',
      itemType: 'DECOR',
      rarity: 'RARE',
      renderKey: 'decor.dinh_lang',
      placeable: true,
      owned: true,
    ),
    CatalogItemDto(
      itemId: 'shop_cay_da',
      code: 'DECOR_CAY_DA',
      name: 'Cây Đa Cổ Thụ',
      description: 'Cây đa cổ thụ che bóng mát đầu làng.',
      category: 'DECOR',
      itemType: 'DECOR',
      rarity: 'COMMON',
      renderKey: 'decor.cay_da',
      placeable: true,
      owned: true,
    ),
    CatalogItemDto(
      itemId: 'item_decor_gieng_co',
      code: 'DECOR_GIENG_CO',
      name: 'Giếng Cổ Đá Xanh',
      description: 'Giếng làng xây bằng đá xanh rêu phong.',
      category: 'DECOR',
      itemType: 'DECOR',
      rarity: 'COMMON',
      renderKey: 'decor.gieng_co',
      placeable: true,
      owned: true,
    ),
    CatalogItemDto(
      itemId: 'item_decor_cot_co',
      code: 'DECOR_COT_CO',
      name: 'Cột cờ truyền thống',
      description: 'Cột cờ lễ hội thêu hoa văn cổ truyền.',
      category: 'DECOR',
      itemType: 'DECOR',
      rarity: 'UNCOMMON',
      renderKey: 'decor.cot_co',
      placeable: true,
      owned: true,
    ),
    CatalogItemDto(
      itemId: 'item_decor_thuyen_rong',
      code: 'DECOR_THUYEN_RONG',
      name: 'Thuyền Rồng Bến Nước',
      description: 'Chiếc thuyền truyền thống neo đậu bên bến nước.',
      category: 'DECOR',
      itemType: 'DECOR',
      rarity: 'RARE',
      renderKey: 'decor.thuyen_rong',
      placeable: true,
      owned: true,
    ),
    CatalogItemDto(
      itemId: 'item_decor_tuong_ly_thai_to',
      code: 'DECOR_TUONG_LY_THAI_TO',
      name: 'Tượng Lý Thái Tổ',
      description: 'Mô hình tượng đài vua Lý Thái Tổ cầm Chiếu dời đô.',
      category: 'DECOR',
      itemType: 'DECOR',
      rarity: 'RARE',
      renderKey: 'decor.tuong_ly_thai_to',
      placeable: true,
      owned: true,
    ),
    CatalogItemDto(
      itemId: 'item_decor_cay_dao',
      code: 'DECOR_CAY_DAO',
      name: 'Cây đào cổ thụ',
      description: 'Cây đào mùa xuân nở hoa hồng thắm.',
      category: 'DECOR',
      itemType: 'DECOR',
      rarity: 'UNCOMMON',
      renderKey: 'decor.cay_dao',
      placeable: true,
      owned: true,
    ),
    CatalogItemDto(
      itemId: 'item_decor_den_long',
      code: 'DECOR_DEN_LONG_HOI_AN',
      name: 'Đèn Lồng Phố Cổ',
      description: 'Cụm đèn lồng lụa rực rỡ thắp sáng góc Đảo Di Sản.',
      category: 'DECOR',
      itemType: 'DECOR',
      rarity: 'UNCOMMON',
      renderKey: 'decor.den_long_hoi_an',
      placeable: true,
      owned: true,
    ),
    CatalogItemDto(
      itemId: 'item_decor_nha_rong',
      code: 'DECOR_NHA_RONG',
      name: 'Nhà rông',
      description: 'Biểu tượng văn hóa cộng đồng của người Việt.',
      category: 'DECOR',
      itemType: 'DECOR',
      rarity: 'RARE',
      renderKey: 'decor.nha_rong',
      placeable: true,
      owned: true,
    ),
    CatalogItemDto(
      itemId: 'item_decor_chua_co',
      code: 'DECOR_CHUA_CO',
      name: 'Chùa cổ',
      description:
          'Ngôi chùa cổ thanh tịnh mang đậm dấu ấn kiến trúc truyền thống Việt Nam.',
      category: 'DECOR',
      itemType: 'DECOR',
      rarity: 'RARE',
      renderKey: 'decor.chua_co',
      placeable: true,
      owned: true,
    ),
    CatalogItemDto(
      itemId: 'item_decor_thap_cham',
      code: 'DECOR_THAP_CHAM',
      name: 'Tháp Chăm',
      description: 'Tuyệt tác kiến trúc gạch nung Chămpa cổ đại trên Đảo Di Sản.',
      category: 'DECOR',
      itemType: 'DECOR',
      rarity: 'EPIC',
      renderKey: 'decor.thap_cham',
      placeable: true,
      owned: true,
    ),
    CatalogItemDto(
      itemId: 'item_decor_tre_truc',
      code: 'DECOR_TRE_TRUC',
      name: 'Tre trúc',
      description:
          'Lũy tre xanh kiên cường gắn liền với làng quê và lịch sử dân tộc.',
      category: 'DECOR',
      itemType: 'DECOR',
      rarity: 'COMMON',
      renderKey: 'decor.tre_truc',
      placeable: true,
      owned: true,
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
