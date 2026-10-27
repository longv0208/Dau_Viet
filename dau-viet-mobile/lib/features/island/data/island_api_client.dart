import '../../../core/api/api_client.dart';
import 'island_dto.dart';

/// API Client kết nối các endpoints Đảo Di Sản, Cửa Hàng & Ví người học.
class IslandApiClient {
  final ApiClient _client;

  const IslandApiClient(this._client);

  /// Lấy thông tin trạng thái đảo hiện tại (tier, tiến độ, danh sách slots).
  Future<IslandDto> getIsland() async {
    final json = await _client.get('/api/v1/me/island');
    return IslandDto.fromJson(json);
  }

  /// Nâng cấp đảo sang tier tiếp theo khi canUpgrade == true.
  Future<IslandDto> upgradeIsland(int expectedRevision) async {
    final json = await _client.post(
      '/api/v1/me/island/upgrade',
      body: {'expectedRevision': expectedRevision},
    );
    return IslandDto.fromJson(json);
  }

  /// Đặt vật phẩm vào slot với Idempotency-Key và kiểm tra expectedRevision.
  Future<IslandDto> placeItem({
    required String slotId,
    required String itemId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    final json = await _client.put(
      '/api/v1/me/island/placements/$slotId',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {'itemId': itemId, 'expectedRevision': expectedRevision},
    );
    return IslandDto.fromJson(json);
  }

  /// Gỡ vật phẩm khỏi slot và cất về kho với expectedRevision.
  Future<IslandDto> removePlacement({
    required String slotId,
    required int expectedRevision,
    String? idempotencyKey,
  }) async {
    final json = await _client.delete(
      '/api/v1/me/island/placements/$slotId',
      headers: idempotencyKey != null
          ? {'Idempotency-Key': idempotencyKey}
          : null,
      body: {'expectedRevision': expectedRevision},
    );
    return IslandDto.fromJson(json);
  }

  /// Lấy danh mục vật phẩm trong Cửa hàng Điểm Sử Ký.
  Future<List<ShopItemDto>> getShopItems() async {
    final raw = await _client.getList('/api/v1/shop/items');
    return raw
        .whereType<Map>()
        .map((e) => ShopItemDto.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Mua vật phẩm từ shop bằng Điểm Sử Ký.
  Future<Map<String, dynamic>> purchaseItem({
    required String itemId,
    required String idempotencyKey,
  }) async {
    return _client.post(
      '/api/v1/me/shop/purchases',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {'itemId': itemId},
    );
  }

  /// Lấy số dư ví của learner.
  Future<WalletDto> getWallet() async {
    final json = await _client.get('/api/v1/me/wallet');
    return WalletDto.fromJson(json);
  }
}
