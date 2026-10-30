import '../../../core/api/api_error.dart';
import '../../../core/api/api_exception.dart';
import 'island_dto.dart';
import 'island_fixture.dart';
import 'island_repository.dart';

/// Mock repository phục vụ demo offline hoặc khi USE_MOCK=true.
class MockIslandRepository implements IslandRepository {
  late IslandDto _island;
  late List<ShopItemDto> _shopItems;
  late WalletDto _wallet;
  final Set<String> _ownedItemIds = {
    'item_decor_nha_tranh',
    'item_decor_cau_kieu',
  };

  MockIslandRepository() {
    _reset();
  }

  void _reset() {
    _wallet = const WalletDto(historyPoints: 500, exp: 1200);
    _island = IslandFixture.createHeritageVillageFixture(tier: 1);

    _shopItems = [
      const ShopItemDto(
        itemId: 'shop_cay_da',
        code: 'decor_cay_da',
        name: 'Cây Đa Di Sản',
        description:
            'Cây đa cổ thụ che bóng mát cho di sản đảo, kết nối cội nguồn.',
        category: 'DECOR',
        pricePoints: 100,
        purchasable: true,
        renderKey: 'decor_cay_da',
        owned: false,
      ),
      const ShopItemDto(
        itemId: 'item_decor_nha_tranh',
        code: 'decor_nha_tranh',
        name: 'Nhà Tranh Cổ Truyền',
        description: 'Kiến trúc mộc mạc lưu giữ hồn quê Việt thời Ngô dựng cờ.',
        category: 'DECOR',
        pricePoints: 200,
        purchasable: true,
        renderKey: 'decor_nha_tranh',
        owned: true,
      ),
      const ShopItemDto(
        itemId: 'shop_ho_sen',
        code: 'decor_ho_sen',
        name: 'Thủy Tạ Hồ Sen',
        description:
            'Đầm sen thơm ngát, điểm tô cảnh sắc thanh tịnh cho đảo di sản.',
        category: 'DECOR',
        pricePoints: 300,
        purchasable: true,
        renderKey: 'decor_ho_sen',
        owned: false,
      ),
      const ShopItemDto(
        itemId: 'item_dinh_lang',
        code: 'decor_dinh_lang',
        name: 'Đình Làng Mái Đao',
        description: 'Ngôi đình cổ với mái đao cong vút trang trí Đảo Di Sản.',
        category: 'DECOR',
        pricePoints: 250,
        purchasable: true,
        renderKey: 'decor.dinh_lang',
        owned: true,
      ),
      const ShopItemDto(
        itemId: 'item_decor_gieng_co',
        code: 'decor_gieng_co',
        name: 'Giếng Cổ Đá Xanh',
        description: 'Giếng làng xây bằng đá xanh rêu phong.',
        category: 'DECOR',
        pricePoints: 150,
        purchasable: true,
        renderKey: 'decor.gieng_co',
        owned: true,
      ),
      const ShopItemDto(
        itemId: 'item_decor_cot_co',
        code: 'decor_cot_co',
        name: 'Cột cờ truyền thống',
        description: 'Cột cờ lễ hội thêu hoa văn cổ truyền.',
        category: 'DECOR',
        pricePoints: 160,
        purchasable: true,
        renderKey: 'decor.cot_co',
        owned: true,
      ),
      const ShopItemDto(
        itemId: 'item_decor_thuyen_rong',
        code: 'decor_thuyen_rong',
        name: 'Thuyền Rồng Bến Nước',
        description: 'Chiếc thuyền rồng neo đậu bên bến nước.',
        category: 'DECOR',
        pricePoints: 280,
        purchasable: true,
        renderKey: 'decor.thuyen_rong',
        owned: true,
      ),
      const ShopItemDto(
        itemId: 'item_decor_tuong_ly_thai_to',
        code: 'decor_tuong_ly_thai_to',
        name: 'Tượng Lý Thái Tổ',
        description: 'Mô hình tượng đài vua Lý Thái Tổ cầm Chiếu dời đô.',
        category: 'DECOR',
        pricePoints: 260,
        purchasable: true,
        renderKey: 'decor.tuong_ly_thai_to',
        owned: true,
      ),
      const ShopItemDto(
        itemId: 'item_decor_cay_dao',
        code: 'decor_cay_dao',
        name: 'Cây đào cổ thụ',
        description: 'Cây đào mùa xuân nở hoa hồng thắm.',
        category: 'DECOR',
        pricePoints: 190,
        purchasable: true,
        renderKey: 'decor.cay_dao',
        owned: true,
      ),
      const ShopItemDto(
        itemId: 'item_decor_den_long',
        code: 'decor_den_long_hoi_an',
        name: 'Đèn Lồng Phố Cổ',
        description: 'Cụm đèn lồng lụa rực rỡ thắp sáng góc Đảo Di Sản.',
        category: 'DECOR',
        pricePoints: 200,
        purchasable: true,
        renderKey: 'decor.den_long_hoi_an',
        owned: true,
      ),
    ];
  }

  @override
  Future<IslandDto> getIsland() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _island;
  }

  @override
  Future<IslandDto> upgradeIsland(int expectedRevision) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (expectedRevision != _island.rowVersion) {
      throw const ApiException(
        ApiError(
          code: 'REVISION_CONFLICT',
          message: 'Trạng thái đảo đã thay đổi, vui lòng thử lại.',
        ),
        statusCode: 409,
      );
    }

    final newTier = (_island.tier + 1).clamp(1, _island.maxTier);
    _island = IslandFixture.createHeritageVillageFixture(tier: newTier).copyWith(
      rowVersion: _island.rowVersion + 1,
      canUpgrade: newTier < _island.maxTier,
    );
    return _island;
  }

  @override
  Future<IslandDto> placeItem({
    required String slotId,
    required String itemId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (expectedRevision != _island.rowVersion) {
      throw const ApiException(
        ApiError(
          code: 'REVISION_CONFLICT',
          message: 'Trạng thái đảo đã thay đổi, vui lòng tải lại.',
        ),
        statusCode: 409,
      );
    }

    // Tìm thông tin vật phẩm từ shop hoặc inventory
    final shopItem = _shopItems.cast<ShopItemDto?>().firstWhere(
      (s) => s?.itemId == itemId,
      orElse: () => null,
    );

    final String name = shopItem?.name ?? 'Vật Phẩm Trang Trí';
    final String code = shopItem?.code ?? 'decor_generic';
    final String renderKey = shopItem?.renderKey ?? code;

    final updatedSlots = _island.slots.map((s) {
      if (s.slotId == slotId) {
        return s.copyWith(
          placement: () => IslandPlacementDto(
            itemId: itemId,
            code: code,
            name: name,
            renderKey: renderKey,
          ),
        );
      }
      return s;
    }).toList();

    _island = _island.copyWith(
      rowVersion: _island.rowVersion + 1,
      slots: updatedSlots,
    );
    return _island;
  }

  @override
  Future<IslandDto> removePlacement({
    required String slotId,
    required int expectedRevision,
    String? idempotencyKey,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (expectedRevision != _island.rowVersion) {
      throw const ApiException(
        ApiError(
          code: 'REVISION_CONFLICT',
          message: 'Trạng thái đảo đã thay đổi, vui lòng tải lại.',
        ),
        statusCode: 409,
      );
    }

    final updatedSlots = _island.slots.map((s) {
      if (s.slotId == slotId) {
        return s.copyWith(placement: () => null);
      }
      return s;
    }).toList();

    _island = _island.copyWith(
      rowVersion: _island.rowVersion + 1,
      slots: updatedSlots,
    );
    return _island;
  }

  @override
  Future<List<ShopItemDto>> getShopItems() async {
    await Future.delayed(const Duration(milliseconds: 150));
    // Enrich with ownership from _ownedItemIds
    return _shopItems.map((item) {
      return ShopItemDto(
        itemId: item.itemId,
        code: item.code,
        name: item.name,
        description: item.description,
        category: item.category,
        pricePoints: item.pricePoints,
        purchasable: item.purchasable,
        owned: _ownedItemIds.contains(item.itemId),
        renderKey: item.renderKey,
        assetId: item.assetId,
        placeable: item.placeable,
      );
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> purchaseItem({
    required String itemId,
    required String idempotencyKey,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final item = _shopItems.cast<ShopItemDto?>().firstWhere(
      (s) => s?.itemId == itemId,
      orElse: () => null,
    );
    if (item == null) {
      throw const ApiException(
        ApiError(code: 'ITEM_NOT_FOUND', message: 'Không tìm thấy vật phẩm.'),
        statusCode: 404,
      );
    }

    if (_wallet.historyPoints < item.price) {
      throw const ApiException(
        ApiError(
          code: 'INSUFFICIENT_FUNDS',
          message: 'Bạn không đủ Điểm Sử Ký để mua vật phẩm này.',
        ),
        statusCode: 400,
      );
    }

    _wallet = WalletDto(
      historyPoints: _wallet.historyPoints - item.price,
      exp: _wallet.exp,
    );
    _ownedItemIds.add(itemId);

    return {
      'success': true,
      'itemId': itemId,
      'remainingPoints': _wallet.historyPoints,
    };
  }

  @override
  Future<WalletDto> getWallet() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _wallet;
  }
}
