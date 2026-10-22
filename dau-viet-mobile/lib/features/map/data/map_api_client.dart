import '../../../core/api/api_client.dart';
import 'map_location_dto.dart';

/// Client mỏng cho `/api/v1/map` — chỉ gọi HTTP + parse DTO.
class MapApiClient {
  final ApiClient _client;

  const MapApiClient(this._client);

  /// `GET /api/v1/map/locations` — trả mảng top-level.
  Future<List<MapLocationDto>> listLocations() async {
    final List<dynamic> json = await _client.getList('/api/v1/map/locations');
    return json
        .cast<Map<String, dynamic>>()
        .map(MapLocationDto.fromJson)
        .toList();
  }
}
