import 'package:dau_viet_mobile/features/energy/data/energy_dto.dart';
import 'package:dau_viet_mobile/features/energy/data/energy_repository.dart';

/// Scripted repo cho provider/widget test — KHÔNG phải MockEnergyRepository
/// của app (mock chỉ phục vụ USE_MOCK). Đếm số lần fetch để test không
/// vô tình poll API.
class FakeEnergyRepository implements EnergyRepository {
  EnergyStateDto next = EnergyStateDto(
    current: 50,
    max: 100,
    recoveryAmount: 5,
    recoveryIntervalSeconds: 900,
    canSubmitGraded: true,
  );

  Object? error;
  int calls = 0;

  /// Trả response khác nhau mỗi lần (queue) — để test refresh đổi data.
  final List<EnergyStateDto> queue = [];

  @override
  Future<EnergyStateDto> getMyEnergy() async {
    calls++;
    if (error != null) throw error!;
    if (queue.isNotEmpty) return queue.removeAt(0);
    return next;
  }
}
