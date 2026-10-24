import 'collection_api_client.dart';
import 'collection_dto.dart';
import 'collection_repository.dart';
import 'dossier_dto.dart';
import 'event_progress_dto.dart';

/// Real repository — gọi backend `/api/v1/me/collection` qua
/// CollectionApiClient. Không fallback mock: lỗi API lan truyền nguyên trạng.
class ApiCollectionRepository implements CollectionRepository {
  final CollectionApiClient _client;

  const ApiCollectionRepository(this._client);

  @override
  Future<CollectionPageDto> list({
    String? type,
    String? eventId,
    int page = 0,
    int size = 20,
  }) => _client.list(type: type, eventId: eventId, page: page, size: size);

  @override
  Future<CollectionItemDto> detail(String evidenceId) =>
      _client.detail(evidenceId);

  @override
  Future<List<String>> availableTypes() => _client.availableTypes();

  /* ---------- GAME-04 dossier ---------- */

  @override
  Future<DossierPageDto> listDossiers({
    String? type,
    String? eventId,
    bool? unlocked,
    int page = 0,
    int size = 20,
  }) => _client.listDossiers(
    type: type,
    eventId: eventId,
    unlocked: unlocked,
    page: page,
    size: size,
  );

  @override
  Future<DossierDetailDto> dossierDetail(String dossierId) =>
      _client.dossierDetail(dossierId);

  @override
  Future<EventProgressDto> eventProgress(String eventId) =>
      _client.eventProgress(eventId);
}
