import '../../../mock/models/lesson_models.dart';
import '../../../mock/models/timeline_models.dart';

/// Kết quả một trang sự kiện đã map sang UI model.
class EventsPageResult {
  final List<TimelineMilestoneModel> milestones;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  const EventsPageResult({
    required this.milestones,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });
}

/// Hợp đồng repository Sự kiện Lịch sử.
/// Presentation chỉ phụ thuộc interface này — API impl và Mock impl
/// hoán đổi qua `eventsRepositoryProvider` (xem events_providers.dart).
abstract class EventsRepository {
  /// Danh sách sự kiện đã publish cho Trục Thời Gian.
  Future<EventsPageResult> getEvents({
    int page = 0,
    int size = 20,
    String sort = 'startYear,asc',
  });

  /// Chi tiết một sự kiện theo UUID backend (hoặc id mock trong chế độ demo).
  /// Ném `ApiException` (`EVENT_NOT_FOUND`) khi không tồn tại.
  Future<HistoricalEventModel> getEventById(String id);
}
