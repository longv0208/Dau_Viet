/// DTO khớp contract `GET /api/v1/events` trong
/// docs/backend-flutter-contract-notes.md §1.
/// Parse chặt bằng `as` — field bắt buộc sai kiểu sẽ ném lỗi rõ ràng
/// thay vì âm thầm thành null.
class HistoricalEventSummaryDto {
  final String id;
  final String slug;
  final String title;
  final String era;
  final String period;
  final int startYear;
  final String summary;
  final String? coverAssetKey;
  final List<String> tags;

  const HistoricalEventSummaryDto({
    required this.id,
    required this.slug,
    required this.title,
    required this.era,
    required this.period,
    required this.startYear,
    required this.summary,
    this.coverAssetKey,
    this.tags = const [],
  });

  factory HistoricalEventSummaryDto.fromJson(Map<String, dynamic> json) {
    return HistoricalEventSummaryDto(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      era: json['era'] as String,
      period: json['period'] as String,
      startYear: (json['startYear'] as num).toInt(),
      summary: json['summary'] as String,
      coverAssetKey: json['coverAssetKey'] as String?,
      tags: json['tags'] is List
          ? (json['tags'] as List).cast<String>()
          : const [],
    );
  }
}

/// DTO khớp `GET /api/v1/events/{id}` — thêm description/location/publishedAt.
class HistoricalEventDetailDto extends HistoricalEventSummaryDto {
  final String? description;
  final String? location;
  final String? publishedAt;

  const HistoricalEventDetailDto({
    required super.id,
    required super.slug,
    required super.title,
    required super.era,
    required super.period,
    required super.startYear,
    required super.summary,
    super.coverAssetKey,
    super.tags,
    this.description,
    this.location,
    this.publishedAt,
  });

  factory HistoricalEventDetailDto.fromJson(Map<String, dynamic> json) {
    return HistoricalEventDetailDto(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      era: json['era'] as String,
      period: json['period'] as String,
      startYear: (json['startYear'] as num).toInt(),
      summary: json['summary'] as String,
      coverAssetKey: json['coverAssetKey'] as String?,
      tags: json['tags'] is List
          ? (json['tags'] as List).cast<String>()
          : const [],
      description: json['description'] as String?,
      location: json['location'] as String?,
      publishedAt: json['publishedAt'] as String?,
    );
  }
}

/// Envelope phân trang của `GET /api/v1/events`.
class EventsPageDto {
  final List<HistoricalEventSummaryDto> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  const EventsPageDto({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  factory EventsPageDto.fromJson(Map<String, dynamic> json) {
    final Object? rawContent = json['content'];
    final List<HistoricalEventSummaryDto> content = rawContent is List
        ? rawContent
            .cast<Map<String, dynamic>>()
            .map(HistoricalEventSummaryDto.fromJson)
            .toList()
        : const [];
    return EventsPageDto(
      content: content,
      page: (json['page'] as num? ?? 0).toInt(),
      size: (json['size'] as num? ?? content.length).toInt(),
      totalElements: (json['totalElements'] as num? ?? content.length).toInt(),
      totalPages: (json['totalPages'] as num? ?? 0).toInt(),
    );
  }
}
