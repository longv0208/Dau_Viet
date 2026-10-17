import '../../../core/api/api_client.dart';
import 'historical_event_dto.dart';

/// Client mỏng cho nhóm endpoint `/api/v1/events` của backend Dấu Việt.
/// Chỉ gọi HTTP + parse DTO — không chứa business logic.
class EventsApiClient {
  final ApiClient _client;

  const EventsApiClient(this._client);

  /// `GET /api/v1/events?page=&size=&sort=`
  Future<EventsPageDto> getEvents({
    int page = 0,
    int size = 20,
    String sort = 'startYear,asc',
  }) async {
    final Map<String, dynamic> json = await _client.get(
      '/api/v1/events',
      query: {'page': page, 'size': size, 'sort': sort},
    );
    return EventsPageDto.fromJson(json);
  }

  /// `GET /api/v1/events/{id}` — [id] truyền thẳng; server tự trả
  /// `MALFORMED_ID`/`EVENT_NOT_FOUND` qua envelope lỗi chuẩn.
  Future<HistoricalEventDetailDto> getEventById(String id) async {
    final Map<String, dynamic> json = await _client.get('/api/v1/events/$id');
    return HistoricalEventDetailDto.fromJson(json);
  }
}
