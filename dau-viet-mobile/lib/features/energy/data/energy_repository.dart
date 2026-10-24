import 'energy_dto.dart';

/// Hợp đồng nguồn dữ liệu Thể lực — presentation chỉ phụ thuộc interface;
/// provider chọn Api (real) hay Mock (demo) theo USE_MOCK.
/// Read-only: không có phương thức cộng/trừ năng lượng.
abstract class EnergyRepository {
  /// GET /api/v1/me/energy — trạng thái Thể lực authoritative của learner.
  Future<EnergyStateDto> getMyEnergy();
}
