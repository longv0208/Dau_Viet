import '../../../core/assets/asset_resolver.dart';
import '../../../mock/models/lesson_models.dart';
import 'event_model_adapter.dart';
import 'events_api_client.dart';
import 'events_repository.dart';
import 'historical_event_dto.dart';

/// `EventsRepository` nối thẳng backend Spring Boot qua [EventsApiClient].
class ApiEventsRepository implements EventsRepository {
  final EventsApiClient _apiClient;
  final AssetResolver _assetResolver;

  const ApiEventsRepository(this._apiClient, this._assetResolver);

  @override
  Future<EventsPageResult> getEvents({
    int page = 0,
    int size = 20,
    String sort = 'startYear,asc',
  }) async {
    final EventsPageDto dto = await _apiClient.getEvents(
      page: page,
      size: size,
      sort: sort,
    );
    // Sự kiện đầu danh sách = chiến dịch đang mở (giữ CTA Bạch Đằng demo).
    final String? activeId = dto.content.isEmpty ? null : dto.content.first.id;
    return EventsPageResult(
      milestones: dto.content
          .map(
            (e) => EventModelAdapter.toTimelineMilestone(
              e,
              activeEventId: activeId,
            ),
          )
          .toList(),
      page: dto.page,
      size: dto.size,
      totalElements: dto.totalElements,
      totalPages: dto.totalPages,
    );
  }

  @override
  Future<HistoricalEventModel> getEventById(String id) async {
    final HistoricalEventDetailDto dto = await _apiClient.getEventById(id);
    return EventModelAdapter.toHistoricalEvent(
      dto,
      heroAssetPath: _assetResolver.resolveEventCover(
        dto.coverAssetKey,
        dto.slug,
      ),
    );
  }
}
