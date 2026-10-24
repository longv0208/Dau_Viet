import '../../../core/api/api_client.dart';
import 'energy_dto.dart';

/// Client mỏng cho `GET /api/v1/me/energy` (GAME-03).
/// Read-only: KHÔNG có endpoint cộng/trừ — penalty/refill chỉ server quyết.
class EnergyApiClient {
  final ApiClient _client;

  const EnergyApiClient(this._client);

  Future<EnergyStateDto> getMyEnergy() async {
    final json = await _client.get('/api/v1/me/energy');
    return EnergyStateDto.fromJson(json);
  }
}
