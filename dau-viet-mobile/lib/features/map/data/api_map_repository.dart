import 'map_api_client.dart';
import 'map_location_dto.dart';
import 'map_repository.dart';

/// Repository thật — ném thẳng `ApiException` lên UI, KHÔNG fallback mock.
class ApiMapRepository implements MapRepository {
  final MapApiClient _api;

  const ApiMapRepository(this._api);

  @override
  Future<List<MapLocationDto>> listLocations() => _api.listLocations();
}
