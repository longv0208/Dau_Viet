import 'energy_dto.dart';
import 'energy_repository.dart';

/// Repository demo (USE_MOCK=true) — trạng thái cố định đầy bình để UI
/// demo không bị chặn. KHÔNG giả lập mua/trừ Điểm Sử Ký; không gọi backend.
class MockEnergyRepository implements EnergyRepository {
  @override
  Future<EnergyStateDto> getMyEnergy() async {
    return EnergyStateDto(
      current: 100,
      max: 100,
      recoveryAmount: 5,
      recoveryIntervalSeconds: 900,
      nextRecoveryAt: null, // đầy → không có mốc chờ
      serverTime: DateTime.now().toUtc(),
      canSubmitGraded: true,
      pointsBalance: 0,
      remedies: const [],
    );
  }

  @override
  Future<EnergyRefillResultDto> refillEnergy({
    required String remedyCode,
    required String idempotencyKey,
  }) {
    // Mock không mô phỏng mua — trả state hiện tại. Demo thật dùng
    // ApiEnergyRepository.
    throw UnimplementedError(
      'MockEnergyRepository does not support refillEnergy — '
      'use real backend for GAME-07',
    );
  }
}
