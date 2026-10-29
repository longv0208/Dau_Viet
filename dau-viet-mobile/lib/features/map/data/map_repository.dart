import 'map_location_dto.dart';

/// Hợp đồng repository Bản đồ Di sản v2 — presentation chỉ phụ thuộc
/// interface này; API impl và Mock impl hoán đổi qua provider.
abstract class MapRepository {
  /// Các địa điểm hiển thị cho learner hiện tại (server tự lọc theo JWT).
  Future<List<MapLocationDto>> listLocations({
    String? periodCode,
    String? eventId,
    String? kind,
    bool? unlocked,
  });

  /// Hồ sơ chi tiết một địa điểm kèm `events[]`, `unlockLessons[]`, `media[]`.
  Future<MapLocationDto> getLocationDetail(String locationId);
}
