import '../../../core/api/api_error.dart';
import '../../../core/api/api_exception.dart';
import '../../../mock/data/mock_bach_dang_data.dart';
import '../../../mock/data/mock_timeline_data.dart';
import '../../../mock/models/lesson_models.dart';
import 'events_repository.dart';

/// `EventsRepository` trả dữ liệu mock — chỉ chạy khi `USE_MOCK=true`.
/// Tái hiện nguyên vẹn hành trình demo Bạch Đằng 938 hiện có.
class MockEventsRepository implements EventsRepository {
  /// UUID seed của backend (profile `local`) — nhận diện được để mock mode
  /// vẫn trả đúng event khi UI điều hướng bằng id thật.
  static const String seedEventId = '00000000-0000-0000-0000-000000000001';

  /// Id mock cũ — giữ cho route fallback `/campaign/evt_bach_dang_938`.
  static const String legacyEventId = 'evt_bach_dang_938';

  @override
  Future<EventsPageResult> getEvents({
    int page = 0,
    int size = 20,
    String sort = 'startYear,asc',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return EventsPageResult(
      milestones: MockTimelineData.milestones,
      page: 0,
      size: MockTimelineData.milestones.length,
      totalElements: MockTimelineData.milestones.length,
      totalPages: 1,
    );
  }

  @override
  Future<HistoricalEventModel> getEventById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (id == seedEventId || id == legacyEventId) {
      return MockBachDangData.event;
    }
    throw const ApiException(
      ApiError(code: 'EVENT_NOT_FOUND', message: 'Không tìm thấy sự kiện.'),
      statusCode: 404,
    );
  }
}
