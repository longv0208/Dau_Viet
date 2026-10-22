import '../../../core/api/api_client.dart';
import 'collection_dto.dart';

/// Client mỏng cho `/api/v1/me/collection` — chỉ HTTP + parse DTO.
class CollectionApiClient {
  final ApiClient _client;

  const CollectionApiClient(this._client);

  Future<CollectionPageDto> list({
    String? type,
    String? eventId,
    int page = 0,
    int size = 20,
  }) async {
    final json = await _client.get(
      '/api/v1/me/collection',
      query: {'page': page, 'size': size, 'type': ?type, 'eventId': ?eventId},
    );
    return CollectionPageDto.fromJson(json);
  }

  Future<CollectionItemDto> detail(String evidenceId) async {
    final json = await _client.get('/api/v1/me/collection/$evidenceId');
    return CollectionItemDto.fromJson(json);
  }

  /// Các evidence_type learner đã collect trên TOÀN collection — nguồn
  /// filter chips đủ loại, không phụ thuộc trang đã tải (P2-D).
  Future<List<String>> availableTypes() async {
    final json = await _client.get('/api/v1/me/collection/types');
    return (json as List).map((e) => e.toString()).toList();
  }
}
