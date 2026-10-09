/// Định nghĩa các loại hình hoạt động học tập tương tác
/// Khớp 100% với UI_COMPONENT_SPEC.md v2.0
enum ActivityType {
  contextReader,     // M-09 Đọc bối cảnh tư liệu
  matching,          // M-11 Ghép nối dữ kiện
  dragOrder,         // M-12 Kéo thả sắp xếp niên đại
  verification,      // M-13 Kiểm chứng giả thuyết
  cerConclusion,     // M-14 Kết luận lập luận CER
  multipleChoice,    // M-16 Trắc nghiệm tư liệu
}

/// Mô hình Sự kiện Lịch sử
class HistoricalEventModel {
  final String id;
  final String title;
  final String era;
  final int year;
  final String heroBannerUrl;
  final String summary;
  final List<String> lessonIds;

  const HistoricalEventModel({
    required this.id,
    required this.title,
    required this.era,
    required this.year,
    required this.heroBannerUrl,
    required this.summary,
    required this.lessonIds,
  });
}

/// Mô hình Bài học (Lesson)
class LessonModel {
  final String id;
  final String eventId;
  final String title;
  final int episodeNumber;
  final String historicalQuestion;
  final List<String> objectives;
  final int energyCost;
  final int historyPointsReward;
  final int xpReward;
  final List<StageModel> stages;

  const LessonModel({
    required this.id,
    required this.eventId,
    required this.title,
    required this.episodeNumber,
    required this.historicalQuestion,
    required this.objectives,
    required this.energyCost,
    required this.historyPointsReward,
    required this.xpReward,
    required this.stages,
  });
}

/// Mô hình Giai đoạn học tập (Stage)
class StageModel {
  final String id;
  final int stageNumber;
  final String title;
  final String subtitle;
  final List<ActivityModel> activities;

  const StageModel({
    required this.id,
    required this.stageNumber,
    required this.title,
    required this.subtitle,
    required this.activities,
  });
}

/// Mô hình Hoạt động học tập (Activity)
class ActivityModel {
  final String id;
  final ActivityType type;
  final String title;
  final String prompt;
  final Map<String, dynamic> config;
  final List<EvidenceRefModel> evidenceRefs;

  const ActivityModel({
    required this.id,
    required this.type,
    required this.title,
    required this.prompt,
    required this.config,
    this.evidenceRefs = const [],
  });
}

/// Mô hình Nguồn chứng cứ khảo cứu
class EvidenceRefModel {
  final String id;
  final String title;
  final String category; // 'Thư tịch cổ' | 'Khảo cổ thực địa'
  final String citation;
  final double reliabilityRating;
  final String? dating;

  const EvidenceRefModel({
    required this.id,
    required this.title,
    required this.category,
    required this.citation,
    required this.reliabilityRating,
    this.dating,
  });
}

/// Mô hình Thẻ Cổ vật di sản (M-21)
class HeritageArtifactModel {
  final String id;
  final String name;
  final String era;
  final String rarity; // 'Thường' | 'Hiếm' | 'Bảo vật Quốc gia'
  final String description;
  final String excavationLocation;
  final String historicalSignificance;

  const HeritageArtifactModel({
    required this.id,
    required this.name,
    required this.era,
    required this.rarity,
    required this.description,
    required this.excavationLocation,
    required this.historicalSignificance,
  });
}
