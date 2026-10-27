// DTO cho nội dung bài học của learner — ánh xạ trực tiếp từ
// `LearnerLessonListItem`, `LearnerLessonMetadata`, `LearnerLessonContent`
// của backend (TASK-0009). Không chứa đáp án riêng tư (backend đã strip).

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

  const LessonListItemDto({
    required this.id,
    required this.title,
    this.centralQuestion,
    this.coverAssetId,
    this.coverImageUrl,
  });

  String? get resolvedCoverAssetId =>
      _extractLearnerAssetId(coverAssetId, coverImageUrl);

  factory LessonListItemDto.fromJson(Map<String, dynamic> json) {
    final rawCoverId = json['coverAssetId']?.toString();
    final rawCoverUrl = json['coverImageUrl'] as String?;
    return LessonListItemDto(
      id: json['id'].toString(),
      title: (json['title'] as String?) ?? '',
      centralQuestion: json['centralQuestion'] as String?,
      coverAssetId: _extractLearnerAssetId(rawCoverId, rawCoverUrl),
      coverImageUrl:
          rawCoverUrl != null && !rawCoverUrl.contains('/admin/')
              ? rawCoverUrl
              : null,
    );
  }
}

class LessonMetadataDto {
  final String id;
  final String? eventId;
  final String title;
  final String? centralQuestion;
  final String? objectivesJson;
  final String? currentVersionId;
  final int versionNo;
  final String? coverAssetId;
  final String? coverImageUrl;

  const LessonMetadataDto({
    required this.id,
    required this.title,
    this.eventId,
    this.centralQuestion,
    this.objectivesJson,
    this.currentVersionId,
    this.versionNo = 1,
    this.coverAssetId,
    this.coverImageUrl,
  });

  String? get resolvedCoverAssetId =>
      _extractLearnerAssetId(coverAssetId, coverImageUrl);

  factory LessonMetadataDto.fromJson(Map<String, dynamic> json) {
    final rawCoverId = json['coverAssetId']?.toString();
    final rawCoverUrl = json['coverImageUrl'] as String?;
    return LessonMetadataDto(
      id: json['id'].toString(),
      eventId: json['eventId']?.toString(),
      title: (json['title'] as String?) ?? '',
      centralQuestion: json['centralQuestion'] as String?,
      objectivesJson: json['objectivesJson'] as String?,
      currentVersionId: json['currentVersionId']?.toString(),
      versionNo: (json['versionNo'] as num?)?.toInt() ?? 1,
      coverAssetId: _extractLearnerAssetId(rawCoverId, rawCoverUrl),
      coverImageUrl:
          rawCoverUrl != null && !rawCoverUrl.contains('/admin/')
              ? rawCoverUrl
              : null,
    );
  }
}

/// Nội dung đã xuất bản của một `lesson_version` — `stages` giữ nguyên dạng
/// Map để các renderer tự đọc `learnerConfig` theo `activity.type` mà không
/// rẽ nhánh theo sự kiện lịch sử.
class LessonContentDto {
  final String lessonId;
  final String lessonVersionId;
  final int versionNo;
  final List<LessonStageDto> stages;
  final List<EvidenceItemDto> evidence;
  final List<AssetItemDto> assets;

  const LessonContentDto({
    required this.lessonId,
    required this.lessonVersionId,
    required this.versionNo,
    required this.stages,
    required this.evidence,
    this.assets = const [],
  });

  factory LessonContentDto.fromJson(Map<String, dynamic> json) {
    final content = (json['content'] is Map)
        ? (json['content'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final rawStages = (content['stages'] as List?) ?? const [];
    final rawEv = (content['evidence'] as List?) ?? const [];
    final rawAs = (content['assets'] as List?) ?? const [];
    return LessonContentDto(
      lessonId: json['lessonId'].toString(),
      lessonVersionId: json['lessonVersionId'].toString(),
      versionNo: (json['versionNo'] as num?)?.toInt() ?? 1,
      stages: rawStages
          .whereType<Map>()
          .map((e) => LessonStageDto.fromJson(e.cast<String, dynamic>()))
          .toList(),
      evidence: rawEv
          .whereType<Map>()
          .map((e) => EvidenceItemDto.fromJson(e.cast<String, dynamic>()))
          .toList(),
      assets: rawAs
          .whereType<Map>()
          .map((e) => AssetItemDto.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  EvidenceItemDto? findEvidence(String id) {
    for (final e in evidence) {
      if (e.id == id) return e;
    }
    return null;
  }

  AssetItemDto? findAsset(String id) {
    for (final a in assets) {
      if (a.id == id) return a;
    }
    return null;
  }
}

class LessonStageDto {
  final String id;
  final String type;
  final String title;
  final List<LessonActivityDto> activities;

  const LessonStageDto({
    required this.id,
    required this.type,
    required this.title,
    this.activities = const [],
  });

  factory LessonStageDto.fromJson(Map<String, dynamic> json) {
    final rawActs = (json['activities'] as List?) ?? const [];
    return LessonStageDto(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      activities: rawActs
          .whereType<Map>()
          .map((e) => LessonActivityDto.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class LessonActivityDto {
  final String id;
  final String type;
  final bool required;
  final String? instruction;
  final Map<String, dynamic> config;

  const LessonActivityDto({
    required this.id,
    required this.type,
    this.required = true,
    this.instruction,
    this.config = const {},
  });

  factory LessonActivityDto.fromJson(Map<String, dynamic> json) {
    final cfg = json['config'];
    return LessonActivityDto(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      required: (json['required'] as bool?) ?? true,
      instruction: json['instruction'] as String?,
      config: (cfg is Map) ? cfg.cast<String, dynamic>() : const {},
    );
  }
}

class EvidenceItemDto {
  final String id;
  final String title;
  final String? kind;
  final String? summary;
  final String? quote;
  final String? attribution;
  final String? assetId;

  const EvidenceItemDto({
    required this.id,
    required this.title,
    this.kind,
    this.summary,
    this.quote,
    this.attribution,
    this.assetId,
  });

  factory EvidenceItemDto.fromJson(Map<String, dynamic> json) =>
      EvidenceItemDto(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        kind: json['kind'] as String?,
        summary: json['summary'] as String?,
        quote: json['quote'] as String?,
        attribution: json['attribution'] as String?,
        assetId: json['assetId']?.toString(),
      );
}

class AssetItemDto {
  final String id;
  final String? mimeType;
  final String? altText;

  const AssetItemDto({required this.id, this.mimeType, this.altText});

  factory AssetItemDto.fromJson(Map<String, dynamic> json) => AssetItemDto(
    id: json['id'].toString(),
    mimeType: json['mimeType'] as String?,
    altText: json['altText'] as String?,
  );
}
