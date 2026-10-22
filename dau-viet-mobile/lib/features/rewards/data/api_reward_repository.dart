import 'reward_api_client.dart';
import 'reward_dtos.dart';
import 'reward_repository.dart';

/// Real repository — gọi backend `/api/v1/me/rewards|inventory` qua
/// RewardApiClient. Không fallback mock: lỗi API lan truyền nguyên trạng.
class ApiRewardRepository implements RewardRepository {
  final RewardApiClient _client;

  const ApiRewardRepository(this._client);

  @override
  Future<RewardSummaryDto> summary() => _client.summary();

  @override
  Future<RewardTransactionPageDto> transactions({
    int page = 0,
    int size = 20,
  }) => _client.transactions(page: page, size: size);

  @override
  Future<List<InventoryItemDto>> inventory() => _client.inventory();

  @override
  Future<List<CatalogItemDto>> catalog() => _client.catalog();
}
