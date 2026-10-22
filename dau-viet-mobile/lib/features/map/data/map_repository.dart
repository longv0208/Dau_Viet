import 'map_location_dto.dart';

/// Hợp đồng repository Bản đồ Lịch sử — presentation chỉ phụ thuộc
/// interface này; API impl và Mock impl hoán đổi qua provider.
abstract class MapRepository {
  /// Các địa điểm hiển thị cho learner hiện tại (server tự lọc theo JWT).
  Future<List<MapLocationDto>> listLocations();
}
