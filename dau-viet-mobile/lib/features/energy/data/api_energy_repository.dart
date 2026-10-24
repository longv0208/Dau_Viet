import 'energy_api_client.dart';
import 'energy_dto.dart';
import 'energy_repository.dart';

/// Repository thật — gọi Spring Boot qua [EnergyApiClient].
/// API lỗi ném thẳng ApiException lên UI; KHÔNG fallback mock (AC-5).
class ApiEnergyRepository implements EnergyRepository {
  final EnergyApiClient _api;

  const ApiEnergyRepository(this._api);

  @override
  Future<EnergyStateDto> getMyEnergy() => _api.getMyEnergy();
}
