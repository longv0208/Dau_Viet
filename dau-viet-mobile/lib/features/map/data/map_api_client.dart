import '../../../core/api/api_client.dart';
import 'map_location_dto.dart';

/// Client mỏng cho `/api/v1/map/locations` (v2) — chỉ gọi HTTP + parse DTO.
class MapApiClient {
  final ApiClient _client;

  const MapApiClient(this._client);

  /// `GET /api/v1/map/locations` — trả mảng địa điểm đã xuất bản kèm trạng thái
  /// mở khoá theo learner. Hỗ trợ lọc tuỳ chọn `periodCode`, `eventId`, `kind`, `unlocked`.
  Future<List<MapLocationDto>> listLocations({
    String? periodCode,
    String? eventId,
    String? kind,
    bool? unlocked,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      if (periodCode != null && periodCode.trim().isNotEmpty)
        'periodCode': periodCode.trim(),
      if (eventId != null && eventId.trim().isNotEmpty)
        'eventId': eventId.trim(),
      if (kind != null && kind.trim().isNotEmpty) 'kind': kind.trim(),
      'unlocked': ?unlocked,
    };
    final List<dynamic> json = await _client.getList(
      '/api/v1/map/locations',
      query: query.isEmpty ? null : query,
    );
    return json
        .whereType<Map>()
        .map((m) => MapLocationDto.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// `GET /api/v1/map/locations/{locationId}` — trả hồ sơ chi tiết địa điểm
  /// kèm `events[]`, `unlockLessons[]` và `media[]` (server tự lọc `UNLOCKED_ONLY`
  /// khi địa điểm chưa mở khoá).
  Future<MapLocationDto> getLocationDetail(String locationId) async {
    final Map<String, dynamic> json = await _client.get(
      '/api/v1/map/locations/$locationId',
    );
    return MapLocationDto.fromJson(json);
  }
}
