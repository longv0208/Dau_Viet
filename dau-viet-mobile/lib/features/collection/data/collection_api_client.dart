import '../../../core/api/api_client.dart';
import 'collection_dto.dart';
import 'dossier_dto.dart';
import 'event_progress_dto.dart';

/// Client mỏng cho `/api/v1/me/collection` + `/me/events/{id}/progress` —
/// chỉ HTTP + parse DTO.
class CollectionApiClient {
  final ApiClient _client;

  const CollectionApiClient(this._client);

  Future<CollectionPageDto> list({
    String? type,
    String? eventId,
    int page = 0,
    int size = 20,
  }) async {
    final json = await _client.get(
      '/api/v1/me/collection',
      query: {'page': page, 'size': size, 'type': ?type, 'eventId': ?eventId},
    );
    return CollectionPageDto.fromJson(json);
  }

  Future<CollectionItemDto> detail(String evidenceId) async {
    final json = await _client.get('/api/v1/me/collection/$evidenceId');
    return CollectionItemDto.fromJson(json);
  }

  /// Các evidence_type learner đã collect trên TOÀN collection — nguồn
  /// filter chips đủ loại, không phụ thuộc trang đã tải (P2-D).
  Future<List<String>> availableTypes() async {
    final json = await _client.get('/api/v1/me/collection/types');
    return (json as List).map((e) => e.toString()).toList();
  }

  /* ---------- GAME-04 dossier ---------- */

  /// List dossier learner thấy được (PUBLISHED + ARCHIVED đã mở).
  Future<DossierPageDto> listDossiers({
    String? type,
    String? eventId,
    bool? unlocked,
    int page = 0,
    int size = 20,
  }) async {
    final json = await _client.get(
      '/api/v1/me/collection/dossiers',
      query: {
        'page': page,
        'size': size,
        'type': ?type,
        'eventId': ?eventId,
        'unlocked': ?unlocked,
      },
    );
    return DossierPageDto.fromJson(json);
  }

  /// Chi tiết dossier — preview khi locked, full khi unlocked.
  Future<DossierDetailDto> dossierDetail(String dossierId) async {
    final json = await _client.get('/api/v1/me/collection/dossiers/$dossierId');
    return DossierDetailDto.fromJson(json);
  }

  /// Tiến độ event của learner — status + required lessons + dossier count.
  /// Đặt trong collection client vì GAME-04 progress là read-side collection.
  Future<EventProgressDto> eventProgress(String eventId) async {
    final json = await _client.get('/api/v1/me/events/$eventId/progress');
    return EventProgressDto.fromJson(json);
  }
}
