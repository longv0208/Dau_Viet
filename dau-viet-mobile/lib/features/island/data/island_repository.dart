import 'island_api_client.dart';
import 'island_dto.dart';

/// Hợp đồng repository cho Đảo Di Sản và Cửa hàng.
abstract class IslandRepository {
  Future<IslandDto> getIsland();

  Future<IslandDto> upgradeIsland(int expectedRevision);

  Future<IslandDto> placeItem({
    required String slotId,
    required String itemId,
    required int expectedRevision,
    required String idempotencyKey,
  });

  Future<IslandDto> removePlacement({
    required String slotId,
    required int expectedRevision,
    String? idempotencyKey,
  });

  Future<List<ShopItemDto>> getShopItems();

  Future<Map<String, dynamic>> purchaseItem({
    required String itemId,
    required String idempotencyKey,
  });

  Future<WalletDto> getWallet();
}

/// Triển khai kết nối backend thật qua [IslandApiClient].
class ApiIslandRepository implements IslandRepository {
  final IslandApiClient _api;

  const ApiIslandRepository(this._api);

  @override
  Future<IslandDto> getIsland() => _api.getIsland();

  @override
  Future<IslandDto> upgradeIsland(int expectedRevision) =>
      _api.upgradeIsland(expectedRevision);

  @override
  Future<IslandDto> placeItem({
    required String slotId,
    required String itemId,
    required int expectedRevision,
    required String idempotencyKey,
  }) => _api.placeItem(
    slotId: slotId,
    itemId: itemId,
    expectedRevision: expectedRevision,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<IslandDto> removePlacement({
    required String slotId,
    required int expectedRevision,
    String? idempotencyKey,
  }) => _api.removePlacement(
    slotId: slotId,
    expectedRevision: expectedRevision,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<List<ShopItemDto>> getShopItems() => _api.getShopItems();

  @override
  Future<Map<String, dynamic>> purchaseItem({
    required String itemId,
    required String idempotencyKey,
  }) => _api.purchaseItem(itemId: itemId, idempotencyKey: idempotencyKey);

  @override
  Future<WalletDto> getWallet() => _api.getWallet();
}
