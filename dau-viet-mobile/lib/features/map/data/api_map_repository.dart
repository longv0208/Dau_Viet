import 'map_api_client.dart';
import 'map_location_dto.dart';
import 'map_repository.dart';

/// Repository thật — ném thẳng `ApiException` lên UI, KHÔNG fallback mock.
class ApiMapRepository implements MapRepository {
  final MapApiClient _api;

  const ApiMapRepository(this._api);

  @override
  Future<List<MapLocationDto>> listLocations({
    String? periodCode,
    String? eventId,
    String? kind,
    bool? unlocked,
  }) => _api.listLocations(
    periodCode: periodCode,
    eventId: eventId,
    kind: kind,
    unlocked: unlocked,
  );

  @override
  Future<MapLocationDto> getLocationDetail(String locationId) =>
      _api.getLocationDetail(locationId);
}
