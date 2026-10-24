/// DTO cho GET /me/events/{id}/progress (GAME-04 §10).
/// `status` ∈ NOT_CONFIGURED | IN_PROGRESS | EVENT_COMPLETED | EVENT_MASTERED.
/// `bestKnowledgeScore` null khi lesson không đo được (NOT_ASSESSED) hoặc
/// chưa completed — không lộ điểm bài không chấm.
library;

class RequiredLessonProgressDto {
  final String lessonId;
  final String? title;
  final bool completed;

  /// MASTERED | BELOW_THRESHOLD | NOT_ASSESSED | NOT_COMPLETED
  final String masteryStatus;
  final double? bestKnowledgeScore;

  const RequiredLessonProgressDto({
    required this.lessonId,
    this.title,
    required this.completed,
    required this.masteryStatus,
    this.bestKnowledgeScore,
  });

  factory RequiredLessonProgressDto.fromJson(Map<String, dynamic> json) =>
      RequiredLessonProgressDto(
        lessonId: json['lessonId'] as String? ?? '',
        title: json['title'] as String?,
        completed: json['completed'] as bool? ?? false,
        masteryStatus: json['masteryStatus'] as String? ?? 'NOT_COMPLETED',
        bestKnowledgeScore: (json['bestKnowledgeScore'] as num?)?.toDouble(),
      );
}

class EventProgressDto {
  final String eventId;
  final String status;
  final int? policyVersion;
  final int requiredLessonsTotal;
  final int requiredLessonsCompleted;
  final bool eventCompleted;
  final bool eventMastered;
  final int? masteryThreshold;
  final List<RequiredLessonProgressDto> requiredLessons;
  final int unlockedDossiersCount;

  /// Policy version đã cấp milestone (FIX 7). Khi admin publish v2 sau khi
  /// learner đã completed v1 → earnedPolicyVersion < policyVersion; UI giải
  /// thích "đã hoàn thành phiên bản trước, còn bài mới để khám phá".
  final int? earnedPolicyVersion;

  const EventProgressDto({
    required this.eventId,
    required this.status,
    this.policyVersion,
    this.requiredLessonsTotal = 0,
    this.requiredLessonsCompleted = 0,
    this.eventCompleted = false,
    this.eventMastered = false,
    this.masteryThreshold,
    this.requiredLessons = const [],
    this.unlockedDossiersCount = 0,
    this.earnedPolicyVersion,
  });

  /// Tỉ lệ 0..1 cho progress bar — null khi NOT_CONFIGURED.
  double? get fraction => requiredLessonsTotal <= 0
      ? null
      : requiredLessonsCompleted / requiredLessonsTotal;

  factory EventProgressDto.fromJson(Map<String, dynamic> json) =>
      EventProgressDto(
        eventId: json['eventId'] as String? ?? '',
        status: json['status'] as String? ?? 'NOT_CONFIGURED',
        policyVersion: (json['policyVersion'] as num?)?.toInt(),
        requiredLessonsTotal:
            (json['requiredLessonsTotal'] as num?)?.toInt() ?? 0,
        requiredLessonsCompleted:
            (json['requiredLessonsCompleted'] as num?)?.toInt() ?? 0,
        eventCompleted: json['eventCompleted'] as bool? ?? false,
        eventMastered: json['eventMastered'] as bool? ?? false,
        masteryThreshold: (json['masteryThreshold'] as num?)?.toInt(),
        requiredLessons: (json['requiredLessons'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (e) =>
                  RequiredLessonProgressDto.fromJson(e.cast<String, dynamic>()),
            )
            .toList(),
        unlockedDossiersCount:
            (json['unlockedDossiersCount'] as num?)?.toInt() ?? 0,
        earnedPolicyVersion: (json['earnedPolicyVersion'] as num?)?.toInt(),
      );
}
