import '../../../core/api/api_client.dart';
import 'energy_dto.dart';

/// Client mỏng cho `/api/v1/me/energy*` (GAME-03 + GAME-07 Issue #28).
/// Server quyết mọi số liệu; client chỉ gửi intent + Idempotency-Key.
class EnergyApiClient {
  final ApiClient _client;

  const EnergyApiClient(this._client);

  Future<EnergyStateDto> getMyEnergy() async {
    final json = await _client.get('/api/v1/me/energy');
    return EnergyStateDto.fromJson(json);
  }

  /// GAME-07: refill Thể lực bằng vật phẩm Viện Thái Y.
  /// `idempotencyKey` BẮT BUỘC — backend trả 400 nếu thiếu.
  Future<EnergyRefillResultDto> refillEnergy({
    required String remedyCode,
    required String idempotencyKey,
  }) async {
    final json = await _client.post(
      '/api/v1/me/energy/refills',
      body: {'remedyCode': remedyCode},
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return EnergyRefillResultDto.fromJson(json);
  }
}
