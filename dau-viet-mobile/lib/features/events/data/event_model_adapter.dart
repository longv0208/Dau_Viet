import '../../../mock/models/lesson_models.dart';
import '../../../mock/models/timeline_models.dart';
import 'historical_event_dto.dart';

/// Adapter DTO backend → UI model hiện hữu, theo bảng map trong
/// docs/backend-flutter-contract-notes.md §2.
/// Không chứa literal theo-từng-sự-kiện (`if (slug == 'bach-dang-938')`).
class EventModelAdapter {
  EventModelAdapter._();

  /// `HistoricalEventSummaryDto` → `TimelineMilestoneModel`.
  /// [activeEventId]: id sự kiện đang mở chiến dịch (hiện CTA);
  /// do provider quyết định — hiện là sự kiện đầu danh sách.
  static TimelineMilestoneModel toTimelineMilestone(
    HistoricalEventSummaryDto dto, {
    String? activeEventId,
  }) {
    return TimelineMilestoneModel(
      id: dto.id,
      yearLabel: dto.period,
      yearValue: dto.startYear,
      title: dto.title,
      subtitle: dto.period,
      description: dto.summary,
      era: dto.era,
      isActive: dto.id == activeEventId,
      eventId: dto.id,
      badgeText: dto.tags.isNotEmpty ? dto.tags.first : null,
    );
  }

  /// `HistoricalEventDetailDto` → `HistoricalEventModel`.
  /// [heroAssetPath] do `AssetResolver` trả về; null → chuỗi rỗng và
  /// `EventCoverImage` sẽ render placeholder (AC-6).
  /// `lessonIds` để trống — lessons endpoint thuộc task sau.
  static HistoricalEventModel toHistoricalEvent(
    HistoricalEventDetailDto dto, {
    String? heroAssetPath,
  }) {
    return HistoricalEventModel(
      id: dto.id,
      title: dto.title,
      era: dto.era,
      year: dto.startYear,
      heroBannerUrl: heroAssetPath ?? '',
      summary: dto.summary,
      lessonIds: const [],
    );
  }
}
