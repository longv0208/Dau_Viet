import '../../../core/api/api_client.dart';
import 'reward_dtos.dart';

/// Client mỏng cho nhóm learner endpoints `/api/v1/me/rewards` +
/// `/api/v1/me/inventory` (TASK-0023) — chỉ HTTP + parse DTO, read-only.
/// Mọi grant/unlock đều do server thực hiện trong transaction của
/// complete()/collect; client không bao giờ POST để "nhận" thưởng.
class RewardApiClient {
  final ApiClient _client;

  const RewardApiClient(this._client);

  Future<RewardSummaryDto> summary() async {
    final json = await _client.get('/api/v1/me/rewards/summary');
    return RewardSummaryDto.fromJson(json);
  }

  Future<RewardTransactionPageDto> transactions({
    int page = 0,
    int size = 20,
  }) async {
    final json = await _client.get(
      '/api/v1/me/rewards/transactions',
      query: {'page': page, 'size': size},
    );
    return RewardTransactionPageDto.fromJson(json);
  }

  Future<List<InventoryItemDto>> inventory() async {
    final raw = await _client.getList('/api/v1/me/inventory');
    return raw
        .whereType<Map>()
        .map((e) => InventoryItemDto.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Catalog đầy đủ kèm owned + requirement + progress — một call render
  /// đủ lưới vật phẩm (đã sở hữu / chưa mở khoá).
  Future<List<CatalogItemDto>> catalog() async {
    final raw = await _client.getList('/api/v1/me/inventory/catalog');
    return raw
        .whereType<Map>()
        .map((e) => CatalogItemDto.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
