/// DTO bề mặt learner lesson — khớp LearnerLessonController records.
/// `content` của snapshot giữ nguyên Map vì cấu trúc stages/evidence/assets
/// là free-form JSON do projection sinh ra.
library;
import '../../../core/models/heritage_background_config.dart';

String? _extractLearnerAssetId(String? coverAssetId, String? coverImageUrl) {
  final trimmedId = coverAssetId?.trim();
  if (trimmedId != null && trimmedId.isNotEmpty) {
    return trimmedId;
  }
  final url = coverImageUrl?.trim();
  if (url == null || url.isEmpty || url.contains('/admin/')) {
    return null;
  }
  final match = RegExp(r'/api/v1/assets/([^/]+)/content$').firstMatch(url);
  return match?.group(1);
}

class LessonListItemDto {
  final String id;
  final String title;
  final String? centralQuestion;
  final String? coverAssetId;
  final String? coverImageUrl;
  final HeritageBackgroundConfigDto backgroundConfig;

  const LessonListItemDto({
    required this.id,
    required this.title,
    this.centralQuestion,
    this.coverAssetId,
    this.coverImageUrl,
    this.backgroundConfig = HeritageBackgroundConfigDto.paperDefault,
  });

  String? get resolvedCoverAssetId =>
      _extractLearnerAssetId(coverAssetId, coverImageUrl);

  factory LessonListItemDto.fromJson(Map<String, dynamic> json) {
    final rawCoverId = json['coverAssetId']?.toString();
    final rawCoverUrl = json['coverImageUrl'] as String?;
    return LessonListItemDto(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      centralQuestion: json['centralQuestion'] as String?,
      coverAssetId: _extractLearnerAssetId(rawCoverId, rawCoverUrl),
      coverImageUrl:
          rawCoverUrl != null && !rawCoverUrl.contains('/admin/')
              ? rawCoverUrl
              : null,
      backgroundConfig: json['backgroundConfig'] is Map
          ? HeritageBackgroundConfigDto.fromJson(
              (json['backgroundConfig'] as Map).cast<String, dynamic>(),
            )
          : HeritageBackgroundConfigDto.paperDefault,
    );
  }
}

class LessonMetadataDto {
  final String id;
  final String title;
  final String? centralQuestion;
  final String eventId;
  final String? objectivesJson;
  final String? currentVersionId;
  final int? versionNo;
  final String? publishedAt;
  final String? coverAssetId;
  final String? coverImageUrl;
  final HeritageBackgroundConfigDto backgroundConfig;

  const LessonMetadataDto({
    required this.id,
    required this.title,
    this.centralQuestion,
    required this.eventId,
    this.objectivesJson,
    this.currentVersionId,
    this.versionNo,
    this.publishedAt,
    this.coverAssetId,
    this.coverImageUrl,
    this.backgroundConfig = HeritageBackgroundConfigDto.paperDefault,
  });

  String? get resolvedCoverAssetId =>
      _extractLearnerAssetId(coverAssetId, coverImageUrl);

  factory LessonMetadataDto.fromJson(Map<String, dynamic> json) {
    final rawCoverId = json['coverAssetId']?.toString();
    final rawCoverUrl = json['coverImageUrl'] as String?;
    return LessonMetadataDto(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      centralQuestion: json['centralQuestion'] as String?,
      eventId: json['eventId']?.toString() ?? '',
      objectivesJson: json['objectivesJson'] as String?,
      currentVersionId: json['currentVersionId']?.toString(),
      versionNo: (json['versionNo'] as num?)?.toInt(),
      publishedAt: json['publishedAt'] as String?,
      coverAssetId: _extractLearnerAssetId(rawCoverId, rawCoverUrl),
      coverImageUrl:
          rawCoverUrl != null && !rawCoverUrl.contains('/admin/')
              ? rawCoverUrl
              : null,
      backgroundConfig: json['backgroundConfig'] is Map
          ? HeritageBackgroundConfigDto.fromJson(
              (json['backgroundConfig'] as Map).cast<String, dynamic>(),
            )
          : HeritageBackgroundConfigDto.paperDefault,
    );
  }
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
