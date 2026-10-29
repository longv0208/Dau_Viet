import 'energy_dto.dart';

/// Hợp đồng nguồn dữ liệu Thể lực — presentation chỉ phụ thuộc interface;
/// provider chọn Api (real) hay Mock (demo) theo USE_MOCK.
abstract class EnergyRepository {
  /// GET /api/v1/me/energy — trạng thái Thể lực authoritative của learner.
  /// GAME-07: trả kèm `pointsBalance` + `remedies[]` (catalog Viện Thái Y
  /// với eligible/blockReasons do server quyết).
  Future<EnergyStateDto> getMyEnergy();

  /// GAME-07 (Issue #28): POST /api/v1/me/energy/refills — mua/dùng một
  /// vật phẩm Viện Thái Y. Idempotency-Key bắt buộc — controller phải
  /// sinh UUID v4 mỗi lần bấm để retry mạng không trừ điểm/cộng energy
  /// hai lần.
  Future<EnergyRefillResultDto> refillEnergy({
    required String remedyCode,
    required String idempotencyKey,
  });
}
