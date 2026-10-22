/// DTO cho GET /api/v1/me/collection — khớp CollectionItemResponse backend.
/// `evidence` là bản embedded từ pinned snapshot lúc collect: immutable,
/// không đổi khi admin sửa/archive evidence gốc.
library;

class CollectionItemDto {
  final String evidenceId;
  final String? evidenceType;
  final String? collectedAt;
  final String? eventId;
  final String? eventTitle;
  final String? lessonId;
  final String? lessonTitle;
  final EvidenceSnapshotDto? evidence;

  const CollectionItemDto({
    required this.evidenceId,
    this.evidenceType,
    this.collectedAt,
    this.eventId,
    this.eventTitle,
    this.lessonId,
    this.lessonTitle,
    this.evidence,
  });

  factory CollectionItemDto.fromJson(Map<String, dynamic> json) =>
      CollectionItemDto(
        evidenceId: json['evidenceId'] as String? ?? '',
        evidenceType: json['evidenceType'] as String?,
        collectedAt: json['collectedAt'] as String?,
        eventId: json['eventId'] as String?,
        eventTitle: json['eventTitle'] as String?,
        lessonId: json['lessonId'] as String?,
        lessonTitle: json['lessonTitle'] as String?,
        evidence: json['evidence'] is Map
            ? EvidenceSnapshotDto.fromJson(
                (json['evidence'] as Map).cast<String, dynamic>(),
              )
            : null,
      );

  /// Convenience getters — UI chỉ đọc, không suy diễn thêm.
  String get title => evidence?.title ?? 'Bằng chứng';
  String? get description => evidence?.description;
  String? get assetId => evidence?.assetId;
}

class EvidenceSnapshotDto {
  final String? title;
  final String? description;
  final String? assetId;
  final EvidenceSourceDto? source;

  const EvidenceSnapshotDto({
    this.title,
    this.description,
    this.assetId,
    this.source,
  });

  factory EvidenceSnapshotDto.fromJson(Map<String, dynamic> json) =>
      EvidenceSnapshotDto(
        title: json['title'] as String?,
        description: json['description'] as String?,
        assetId: json['assetId'] as String?,
        source: json['source'] is Map
            ? EvidenceSourceDto.fromJson(
                (json['source'] as Map).cast<String, dynamic>(),
              )
            : null,
      );
}

class EvidenceSourceDto {
  final String? title;
  final String? author;
  final String? url;
  final String? citation;
  final String? publishedAt;

  const EvidenceSourceDto({
    this.title,
    this.author,
    this.url,
    this.citation,
    this.publishedAt,
  });

  factory EvidenceSourceDto.fromJson(Map<String, dynamic> json) =>
      EvidenceSourceDto(
        title: json['title'] as String?,
        author: json['author'] as String?,
        url: json['url'] as String?,
        citation: json['citation'] as String?,
        publishedAt: json['publishedAt'] as String?,
      );
}

/// PageResponse backend envelope.
class CollectionPageDto {
  final List<CollectionItemDto> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  const CollectionPageDto({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  bool get hasMore => page + 1 < totalPages;

  factory CollectionPageDto.fromJson(Map<String, dynamic> json) {
    final raw = json['content'] ?? json['items'];
    return CollectionPageDto(
      content: raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (e) => CollectionItemDto.fromJson(e.cast<String, dynamic>()),
                )
                .toList()
          : const [],
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}
