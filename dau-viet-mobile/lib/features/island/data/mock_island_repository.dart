import '../../../core/api/api_error.dart';
import '../../../core/api/api_exception.dart';
import 'island_dto.dart';
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

    _island = const IslandDto(
      tier: 1,
      maxTier: 3,
      rowVersion: 1,
      currentExp: 1200,
      currentLevel: 3,
      nextTierRequiredLevel: 2,
      nextTierRequiredExp: 500,
      canUpgrade: true,
      eventsCompleted: 1,
      // Layout metadata (ISLAND-03) — mock heritage-village v1
      layoutCode: 'heritage-village',
      layoutVersionNumber: 1,
      canvasWidth: 960.0,
      canvasHeight: 720.0,
      themeKey: 'heritage',
      regions: [
        IslandLayoutRegionDto(
          regionCode: 'TIER_1',
          unlockTier: 1,
          unlocked: true,
          label: 'Khu Trung Tâm',
          boundsJson: '{"x":0.05,"y":0.08,"width":0.90,"height":0.44}',
        ),
        IslandLayoutRegionDto(
          regionCode: 'TIER_2',
          unlockTier: 2,
          unlocked: false,
          label: 'Khu Mở Rộng',
          boundsJson: '{"x":0.05,"y":0.46,"width":0.90,"height":0.28}',
        ),
        IslandLayoutRegionDto(
          regionCode: 'TIER_3',
          unlockTier: 3,
          unlocked: false,
          label: 'Khu Cao Cấp',
          boundsJson: '{"x":0.05,"y":0.68,"width":0.90,"height":0.27}',
        ),
      ],
      sceneLayers: [
        IslandSceneLayerDto(
          layerKey: 'water_bg',
          layerType: 'ANIMATED_WATER',
          renderOrder: 0,
        ),
        IslandSceneLayerDto(
          layerKey: 'island_base',
          layerType: 'STATIC_IMAGE',
          renderOrder: 10,
          assetRef: 'assets/images/dv_ISL_generic_island-base-tiers_v01.jpg',
        ),
        IslandSceneLayerDto(
          layerKey: 'water_ambient',
          layerType: 'AMBIENT_OVERLAY',
          renderOrder: 20,
        ),
        IslandSceneLayerDto(
          layerKey: 'region_fog',
          layerType: 'REGION_OVERLAY',
          renderOrder: 25,
        ),
        IslandSceneLayerDto(
          layerKey: 'item_layer',
          layerType: 'ITEM_LAYER',
          renderOrder: 30,
        ),
      ],
      progress: IslandProgressDto(
        completedEvents: 1,
        nextTierRequiredEvents: 2,
        canUpgrade: true,
      ),
      slots: [
        IslandSlotDto(
          slotId: 'CENTER_01',
          x: 0.50,
          y: 0.45,
          zIndex: 10,
          unlockTier: 1,
          unlocked: true,
          allowedCategories: ['DECOR'],
          placement: IslandPlacementDto(
            itemId: 'item_decor_nha_tranh',
            code: 'decor_nha_tranh',
            name: 'Nhà Tranh Mái Lá',
            renderKey: 'decor_nha_tranh',
          ),
        ),
        IslandSlotDto(
          slotId: 'DOCK_01',
          x: 0.28,
          y: 0.62,
          zIndex: 15,
          unlockTier: 1,
          unlocked: true,
          allowedCategories: ['DECOR'],
          placement: IslandPlacementDto(
            itemId: 'item_decor_cau_kieu',
            code: 'decor_cau_kieu',
            name: 'Cầu Kiều Ao Làng',
            renderKey: 'decor_cau_kieu',
          ),
        ),
        IslandSlotDto(
          slotId: 'POND_01',
          x: 0.72,
          y: 0.55,
          zIndex: 12,
          unlockTier: 1,
          unlocked: true,
          allowedCategories: ['DECOR'],
          placement: null,
        ),
        IslandSlotDto(
          slotId: 'TREE_01',
          x: 0.55,
          y: 0.25,
          zIndex: 5,
          unlockTier: 2,
          unlocked: false,
          allowedCategories: ['DECOR'],
          placement: null,
        ),
      ],
    );

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
    final updatedSlots = _island.slots.map((slot) {
      if (slot.unlockTier <= newTier) {
        return slot.copyWith(unlocked: true);
      }
      return slot;
    }).toList();

    _island = _island.copyWith(
      tier: newTier,
      rowVersion: _island.rowVersion + 1,
      canUpgrade: false,
      progress: const IslandProgressDto(
        completedEvents: 2,
        nextTierRequiredEvents: 4,
        canUpgrade: false,
      ),
      slots: updatedSlots,
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
