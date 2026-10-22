import 'collection_api_client.dart';
import 'collection_dto.dart';
import 'collection_repository.dart';

/// Real repository — gọi backend `/api/v1/me/collection` qua
/// CollectionApiClient. Không fallback mock: lỗi API lan truyền nguyên trạng.
class ApiCollectionRepository implements CollectionRepository {
  final CollectionApiClient _client;

  const ApiCollectionRepository(this._client);

  @override
  Future<CollectionPageDto> list({
    String? type,
    String? eventId,
    int page = 0,
    int size = 20,
  }) => _client.list(type: type, eventId: eventId, page: page, size: size);

  @override
  Future<CollectionItemDto> detail(String evidenceId) =>
      _client.detail(evidenceId);

  @override
  Future<List<String>> availableTypes() => _client.availableTypes();
}
