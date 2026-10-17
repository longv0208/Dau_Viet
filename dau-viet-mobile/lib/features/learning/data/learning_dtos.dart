/// DTO bề mặt learner lesson — khớp LearnerLessonController records.
/// `content` của snapshot giữ nguyên Map vì cấu trúc stages/evidence/assets
/// là free-form JSON do projection sinh ra.
library;

class LessonListItemDto {
  final String id;
  final String title;
  final String? centralQuestion;

  const LessonListItemDto({
    required this.id,
    required this.title,
    this.centralQuestion,
  });

  factory LessonListItemDto.fromJson(Map<String, dynamic> json) =>
      LessonListItemDto(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        centralQuestion: json['centralQuestion'] as String?,
      );
}

class LessonMetadataDto {
  final String id;
  final String title;
  final String? centralQuestion;
  final String eventId;
  final String? currentVersionId;
  final int? versionNo;
  final String? publishedAt;

  const LessonMetadataDto({
    required this.id,
    required this.title,
    this.centralQuestion,
    required this.eventId,
    this.currentVersionId,
    this.versionNo,
    this.publishedAt,
  });

  factory LessonMetadataDto.fromJson(Map<String, dynamic> json) =>
      LessonMetadataDto(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        centralQuestion: json['centralQuestion'] as String?,
        eventId: json['eventId'] as String? ?? '',
        currentVersionId: json['currentVersionId'] as String?,
        versionNo: (json['versionNo'] as num?)?.toInt(),
        publishedAt: json['publishedAt'] as String?,
      );
}

/// GET /api/v1/lessons/{id}/content và /attempts/{id}/content.
/// `content` = projected snapshot: stages[] + evidence[] + assets[] +
/// objectives + completion — giữ Map thô, renderer tự đọc field cần.
class LessonContentDto {
  final String lessonId;
  final String lessonVersionId;
  final int? versionNo;
  final Map<String, dynamic> content;

  const LessonContentDto({
    required this.lessonId,
    required this.lessonVersionId,
    this.versionNo,
    required this.content,
  });

  factory LessonContentDto.fromJson(Map<String, dynamic> json) {
    final Object? raw = json['content'];
    return LessonContentDto(
      lessonId: json['lessonId'] as String? ?? '',
      lessonVersionId: json['lessonVersionId'] as String? ?? '',
      versionNo: (json['versionNo'] as num?)?.toInt(),
      content: raw is Map ? raw.cast<String, dynamic>() : const {},
    );
  }

  List<Map<String, dynamic>> get stages =>
      (content['stages'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

  List<Map<String, dynamic>> get evidence =>
      (content['evidence'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

  List<Map<String, dynamic>> get assets =>
      (content['assets'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

  Map<String, dynamic>? evidenceById(String id) {
    for (final e in evidence) {
      if (e['id'] == id) return e;
    }
    return null;
  }

  Map<String, dynamic>? assetById(String id) {
    for (final a in assets) {
      if (a['id'] == id) return a;
    }
    return null;
  }
}
