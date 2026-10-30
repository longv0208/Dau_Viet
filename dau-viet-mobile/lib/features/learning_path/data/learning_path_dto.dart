/// DTO và mô hình miền cho Lộ Trình Học Tập — Bản Đồ Dấu Ấn 2.0 (Issue #21 / E1).
/// Khớp hợp đồng A2 (`GET /api/v1/me/learning-path`, `GET /api/v1/learning-path`,
/// `POST /api/v1/me/learning-path/periods/{periodCode}/touch`).
library;

import '../../../core/models/heritage_background_config.dart';
export '../../../core/models/heritage_background_config.dart';
/// Mã lộ trình chuẩn hóa xuyên suốt ứng dụng.
const String defaultLearningPathCode = 'HISTORY_MAIN';

/// Loại nút trong cây phân cấp chương trình học (`ERA -> PERIOD -> PHASE`).
enum PathNodeType {
  era,
  period,
  phase;

  /// Parse từ chuỗi JSON backend; mặc định `PERIOD` để tương thích ngược v1.
  static PathNodeType parse(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'ERA':
        return PathNodeType.era;
      case 'PHASE':
        return PathNodeType.phase;
      case 'PERIOD':
      default:
        return PathNodeType.period;
    }
  }

  String get wireValue {
    switch (this) {
      case PathNodeType.era:
        return 'ERA';
      case PathNodeType.period:
        return 'PERIOD';
      case PathNodeType.phase:
        return 'PHASE';
    }
  }

  String get labelVi {
    switch (this) {
      case PathNodeType.era:
        return 'Đại thời kỳ';
      case PathNodeType.period:
        return 'Thời kỳ';
      case PathNodeType.phase:
        return 'Giai đoạn';
    }
  }

  bool get isEra => this == PathNodeType.era;
  bool get isPeriod => this == PathNodeType.period;
  bool get isPhase => this == PathNodeType.phase;
}

/// Trạng thái tiến độ cá nhân của người học trên từng sự kiện hoặc bài học.
enum LearnerPathStatus {
  locked,
  available,
  inProgress,
  completed,
  mastered,
  notReady;

  static LearnerPathStatus parse(
    String? raw, {
    LearnerPathStatus fallback = LearnerPathStatus.locked,
  }) {
    return tryParse(raw) ?? fallback;
  }

  static LearnerPathStatus? tryParse(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'LOCKED':
        return LearnerPathStatus.locked;
      case 'AVAILABLE':
      case 'PUBLISHED':
        return LearnerPathStatus.available;
      case 'IN_PROGRESS':
        return LearnerPathStatus.inProgress;
      case 'COMPLETED':
        return LearnerPathStatus.completed;
      case 'MASTERED':
        return LearnerPathStatus.mastered;
      case 'NOT_READY':
        return LearnerPathStatus.notReady;
      default:
        return null;
    }
  }

  String get wireValue {
    switch (this) {
      case LearnerPathStatus.locked:
        return 'LOCKED';
      case LearnerPathStatus.available:
        return 'AVAILABLE';
      case LearnerPathStatus.inProgress:
        return 'IN_PROGRESS';
      case LearnerPathStatus.completed:
        return 'COMPLETED';
      case LearnerPathStatus.mastered:
        return 'MASTERED';
      case LearnerPathStatus.notReady:
        return 'NOT_READY';
    }
  }

  /// Nhãn tiếng Việt chuẩn cho UI (E2/E3: trạng thái có icon + nhãn rõ ràng).
  String get labelVi {
    switch (this) {
      case LearnerPathStatus.locked:
        return 'Đang khóa';
      case LearnerPathStatus.available:
        return 'Sẵn sàng học';
      case LearnerPathStatus.inProgress:
        return 'Đang học';
      case LearnerPathStatus.completed:
        return 'Đã hoàn thành';
      case LearnerPathStatus.mastered:
        return 'Đã tinh thông';
      case LearnerPathStatus.notReady:
        return 'Đang biên soạn';
    }
  }

  /// Khớp `LearnerPathProgressionService.requireLessonAvailableForNewAttempt`.
  bool get canStart =>
      this == LearnerPathStatus.available ||
      this == LearnerPathStatus.inProgress ||
      this == LearnerPathStatus.completed ||
      this == LearnerPathStatus.mastered;

  bool get isUnlocked => canStart;
  bool get isLocked => this == LearnerPathStatus.locked;
  bool get isAvailable => this == LearnerPathStatus.available;
  bool get isInProgress => this == LearnerPathStatus.inProgress;
  bool get isCompleted => this == LearnerPathStatus.completed;
  bool get isMastered => this == LearnerPathStatus.mastered;
  bool get isDone =>
      this == LearnerPathStatus.completed || this == LearnerPathStatus.mastered;
  bool get isNotReady => this == LearnerPathStatus.notReady;
}

/// Trạng thái biên tập nội dung hệ thống của sự kiện trong lộ trình.
enum PathContentStatus {
  playable,
  noPublishedLesson,
  noCompletionPolicy,
  contentReviewRequired;

  static PathContentStatus parse(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'PLAYABLE':
        return PathContentStatus.playable;
      case 'NO_COMPLETION_POLICY':
        return PathContentStatus.noCompletionPolicy;
      case 'CONTENT_REVIEW_REQUIRED':
        return PathContentStatus.contentReviewRequired;
      case 'NO_PUBLISHED_LESSON':
      default:
        return PathContentStatus.noPublishedLesson;
    }
  }

  String get wireValue {
    switch (this) {
      case PathContentStatus.playable:
        return 'PLAYABLE';
      case PathContentStatus.noPublishedLesson:
        return 'NO_PUBLISHED_LESSON';
      case PathContentStatus.noCompletionPolicy:
        return 'NO_COMPLETION_POLICY';
      case PathContentStatus.contentReviewRequired:
        return 'CONTENT_REVIEW_REQUIRED';
    }
  }

  String get labelVi {
    switch (this) {
      case PathContentStatus.playable:
        return 'Sẵn sàng học';
      case PathContentStatus.noPublishedLesson:
        return 'Chưa có bài học';
      case PathContentStatus.noCompletionPolicy:
        return 'Chưa cấu hình mục tiêu';
      case PathContentStatus.contentReviewRequired:
        return 'Đang rà soát nội dung';
    }
  }

  bool get isPlayable => this == PathContentStatus.playable;
}

/// Vai trò tham gia của sự kiện trong lộ trình (`REQUIRED` hoặc `EXPLORATION_ONLY`).
enum ParticipationType {
  required,
  explorationOnly;

  static ParticipationType parse(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'EXPLORATION_ONLY':
        return ParticipationType.explorationOnly;
      case 'REQUIRED':
      default:
        return ParticipationType.required;
    }
  }

  String get wireValue {
    switch (this) {
      case ParticipationType.required:
        return 'REQUIRED';
      case ParticipationType.explorationOnly:
        return 'EXPLORATION_ONLY';
    }
  }

  String get labelVi {
    switch (this) {
      case ParticipationType.required:
        return 'Bắt buộc';
      case ParticipationType.explorationOnly:
        return 'Khám phá thêm';
    }
  }

  bool get isRequired => this == ParticipationType.required;
  bool get isExplorationOnly => this == ParticipationType.explorationOnly;
}

/// Độ chính xác niên đại của sự kiện lịch sử (`EXACT`, `CIRCA`, `CENTURY`, `PERIOD`).
enum EventDatePrecision {
  exact,
  circa,
  century,
  period;

  static EventDatePrecision parse(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'CIRCA':
        return EventDatePrecision.circa;
      case 'CENTURY':
        return EventDatePrecision.century;
      case 'PERIOD':
        return EventDatePrecision.period;
      case 'EXACT':
      default:
        return EventDatePrecision.exact;
    }
  }

  String get wireValue {
    switch (this) {
      case EventDatePrecision.exact:
        return 'EXACT';
      case EventDatePrecision.circa:
        return 'CIRCA';
      case EventDatePrecision.century:
        return 'CENTURY';
      case EventDatePrecision.period:
        return 'PERIOD';
    }
  }

  String get labelVi {
    switch (this) {
      case EventDatePrecision.exact:
        return 'Chính xác';
      case EventDatePrecision.circa:
        return 'Ước lượng';
      case EventDatePrecision.century:
        return 'Theo thế kỷ';
      case EventDatePrecision.period:
        return 'Theo thời kỳ';
    }
  }
}

typedef DatePrecision = EventDatePrecision;

/// Tổng hợp tiến độ toàn lộ trình (`LearnerLearningPathResponse.Summary`).
class LearningPathSummaryDto {
  final int completedEvents;
  final int totalRequiredEvents;
  final int completedLessons;
  final int totalRequiredLessons;

  const LearningPathSummaryDto({
    this.completedEvents = 0,
    this.totalRequiredEvents = 0,
    this.completedLessons = 0,
    this.totalRequiredLessons = 0,
  });

  double get eventProgressFraction => totalRequiredEvents <= 0
      ? 0.0
      : (completedEvents / totalRequiredEvents).clamp(0.0, 1.0);

  double get lessonProgressFraction => totalRequiredLessons <= 0
      ? 0.0
      : (completedLessons / totalRequiredLessons).clamp(0.0, 1.0);

  factory LearningPathSummaryDto.fromJson(Map<String, dynamic> json) {
    return LearningPathSummaryDto(
      completedEvents: (json['completedEvents'] as num?)?.toInt() ?? 0,
      totalRequiredEvents: (json['totalRequiredEvents'] as num?)?.toInt() ?? 0,
      completedLessons: (json['completedLessons'] as num?)?.toInt() ?? 0,
      totalRequiredLessons:
          (json['totalRequiredLessons'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'completedEvents': completedEvents,
    'totalRequiredEvents': totalRequiredEvents,
    'completedLessons': completedLessons,
    'totalRequiredLessons': totalRequiredLessons,
  };
}

/// Con trỏ vị trí học hiện tại (`LearnerLearningPathResponse.Current`).
class LearningPathCurrentDto {
  final String? chapterId;
  final String? eventNodeId;
  final String? lessonId;

  const LearningPathCurrentDto({
    this.chapterId,
    this.eventNodeId,
    this.lessonId,
  });

  bool get hasTarget =>
      (eventNodeId != null && eventNodeId!.isNotEmpty) ||
      (lessonId != null && lessonId!.isNotEmpty);

  factory LearningPathCurrentDto.fromJson(Map<String, dynamic> json) {
    return LearningPathCurrentDto(
      chapterId: json['chapterId'] as String?,
      eventNodeId: json['eventNodeId'] as String?,
      lessonId: json['lessonId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'chapterId': chapterId,
    'eventNodeId': eventNodeId,
    'lessonId': lessonId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningPathCurrentDto &&
          chapterId == other.chapterId &&
          eventNodeId == other.eventNodeId &&
          lessonId == other.lessonId;

  @override
  int get hashCode => Object.hash(chapterId, eventNodeId, lessonId);
}

typedef PathCurrentDto = LearningPathCurrentDto;

/// Tiến độ theo từng thời kỳ `PERIOD` (`LearnerLearningPathResponse.PeriodProgress`).
class PeriodProgressDto {
  final String chapterId;
  final String code;
  final String title;
  final int completedEvents;
  final int requiredEvents;
  final int completedLessons;
  final int requiredLessons;
  final int percent;

  const PeriodProgressDto({
    required this.chapterId,
    required this.code,
    required this.title,
    this.completedEvents = 0,
    this.requiredEvents = 0,
    this.completedLessons = 0,
    this.requiredLessons = 0,
    this.percent = 0,
  });

  double get fraction => (percent / 100.0).clamp(0.0, 1.0);

  bool get isCompleted =>
      requiredEvents > 0 && completedEvents >= requiredEvents;

  bool get hasStarted => completedEvents > 0 || completedLessons > 0;

  factory PeriodProgressDto.fromJson(Map<String, dynamic> json) {
    return PeriodProgressDto(
      chapterId: json['chapterId'] as String? ?? '',
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      completedEvents: (json['completedEvents'] as num?)?.toInt() ?? 0,
      requiredEvents: (json['requiredEvents'] as num?)?.toInt() ?? 0,
      completedLessons: (json['completedLessons'] as num?)?.toInt() ?? 0,
      requiredLessons: (json['requiredLessons'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'chapterId': chapterId,
    'code': code,
    'title': title,
    'completedEvents': completedEvents,
    'requiredEvents': requiredEvents,
    'completedLessons': completedLessons,
    'requiredLessons': requiredLessons,
    'percent': percent,
  };
}

/// Nút bài học thuộc một sự kiện trong lộ trình.
class LearningPathLessonNodeDto {
  final String? lessonNodeId;
  final String lessonId;
  final String title;
  final int sortOrder;
  final LearnerPathStatus status;
  final String? rawStatus;
  final String? coverAssetId;
  final String? coverImageUrl;
  final HeritageBackgroundConfigDto backgroundConfig;

  const LearningPathLessonNodeDto({
    this.lessonNodeId,
    required this.lessonId,
    required this.title,
    required this.sortOrder,
    required this.status,
    this.rawStatus,
    this.coverAssetId,
    this.coverImageUrl,
    this.backgroundConfig = HeritageBackgroundConfigDto.paperDefault,
  });

  bool get isUnlocked => status.isUnlocked;
  bool get isDone => status.isDone;
  bool get isLocked => status.isLocked;

  factory LearningPathLessonNodeDto.fromJson(Map<String, dynamic> json) {
    final String? raw = json['status'] as String?;
    final rawBg = json['backgroundConfig'];
    return LearningPathLessonNodeDto(
      lessonNodeId: json['lessonNodeId'] as String?,
      lessonId: json['lessonId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      status: LearnerPathStatus.parse(raw),
      rawStatus: raw,
      coverAssetId: json['coverAssetId']?.toString(),
      coverImageUrl: json['coverImageUrl'] as String?,
      backgroundConfig: rawBg is Map
          ? HeritageBackgroundConfigDto.fromJson(rawBg.cast<String, dynamic>())
          : HeritageBackgroundConfigDto.paperDefault,
    );
  }

  Map<String, dynamic> toJson() => {
    if (lessonNodeId != null) 'lessonNodeId': lessonNodeId,
    'lessonId': lessonId,
    'title': title,
    'sortOrder': sortOrder,
    'status': status.wireValue,
    if (coverAssetId != null) 'coverAssetId': coverAssetId,
    if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
    'backgroundConfig': backgroundConfig.toJson(),
  };
}

typedef PathLessonNodeDto = LearningPathLessonNodeDto;
typedef PathLessonDto = LearningPathLessonNodeDto;

/// Nút sự kiện lịch sử thuộc một chương/thời kỳ trong lộ trình.
class LearningPathEventNodeDto {
  final String eventNodeId;
  final String eventId;
  final String? slug;
  final String title;
  final int? startYear;
  final int? endYear;
  final EventDatePrecision datePrecision;
  final String yearLabel;
  final String? period;
  final String? coverAssetKey;
  final HeritageBackgroundConfigDto backgroundConfig;
  final int sortOrder;
  final ParticipationType participationType;
  final LearnerPathStatus status;
  final PathContentStatus contentStatus;
  final List<LearningPathLessonNodeDto> lessons;

  const LearningPathEventNodeDto({
    required this.eventNodeId,
    required this.eventId,
    this.slug,
    required this.title,
    this.startYear,
    this.endYear,
    this.datePrecision = EventDatePrecision.exact,
    required this.yearLabel,
    this.period,
    this.coverAssetKey,
    this.backgroundConfig = HeritageBackgroundConfigDto.paperDefault,
    required this.sortOrder,
    this.participationType = ParticipationType.required,
    this.status = LearnerPathStatus.locked,
    this.contentStatus = PathContentStatus.playable,
    this.lessons = const [],
  });

  /// Alias tương thích với `LearningPathResponse.EventNodeResponse.nodeId`.
  String get nodeId => eventNodeId;

  bool get isRequired => participationType.isRequired;
  bool get isExplorationOnly => participationType.isExplorationOnly;
  bool get isPlayable => contentStatus.isPlayable;
  bool get isUnlocked => status.isUnlocked;
  bool get isDone => status.isDone;

  int get completedLessonsCount => lessons.where((l) => l.status.isDone).length;

  factory LearningPathEventNodeDto.fromJson(Map<String, dynamic> json) {
    final content = PathContentStatus.parse(json['contentStatus'] as String?);
    final String? rawStatus = json['status'] as String?;
    final LearnerPathStatus resolvedStatus = rawStatus != null
        ? LearnerPathStatus.parse(rawStatus)
        : (content.isPlayable
              ? LearnerPathStatus.available
              : LearnerPathStatus.notReady);

    final rawLessons = json['lessons'] as List? ?? const [];
    final lessons =
        rawLessons
            .whereType<Map>()
            .map(
              (e) =>
                  LearningPathLessonNodeDto.fromJson(e.cast<String, dynamic>()),
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return LearningPathEventNodeDto(
      eventNodeId: (json['eventNodeId'] ?? json['nodeId']) as String? ?? '',
      eventId: json['eventId'] as String? ?? '',
      slug: json['slug'] as String?,
      title: json['title'] as String? ?? '',
      startYear: (json['startYear'] as num?)?.toInt(),
      endYear: (json['endYear'] as num?)?.toInt(),
      datePrecision: EventDatePrecision.parse(json['datePrecision'] as String?),
      yearLabel: json['yearLabel'] as String? ?? '',
      period: json['period'] as String?,
      coverAssetKey: json['coverAssetKey'] as String?,
      backgroundConfig: json['backgroundConfig'] is Map
          ? HeritageBackgroundConfigDto.fromJson(
              (json['backgroundConfig'] as Map).cast<String, dynamic>(),
            )
          : HeritageBackgroundConfigDto.paperDefault,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      participationType: ParticipationType.parse(
        json['participationType'] as String?,
      ),
      status: resolvedStatus,
      contentStatus: content,
      lessons: lessons,
    );
  }

  Map<String, dynamic> toJson() => {
    'eventNodeId': eventNodeId,
    'eventId': eventId,
    if (slug != null) 'slug': slug,
    'title': title,
    if (startYear != null) 'startYear': startYear,
    'endYear': endYear,
    'datePrecision': datePrecision.wireValue,
    'yearLabel': yearLabel,
    if (period != null) 'period': period,
    if (coverAssetKey != null) 'coverAssetKey': coverAssetKey,
    'backgroundConfig': backgroundConfig.toJson(),
    'sortOrder': sortOrder,
    'participationType': participationType.wireValue,
    'status': status.wireValue,
    'contentStatus': contentStatus.wireValue,
    'lessons': lessons.map((l) => l.toJson()).toList(),
  };
}

typedef PathEventNodeDto = LearningPathEventNodeDto;
typedef PathEventDto = LearningPathEventNodeDto;

/// Chương / nút phân cấp trong lộ trình (`ERA`, `PERIOD`, `PHASE`).
class LearningPathChapterDto {
  final String chapterId;
  final String? parentId;
  final PathNodeType nodeType;
  final String code;
  final String title;
  final String? description;
  final int? startYear;
  final int? endYear;
  final String? periodLabel;
  final int sortOrder;
  final String? themeKey;

  /// Khóa ảnh bìa hiển thị trên thẻ thời kỳ (do admin cấu hình trong CMS).
  /// Dạng `periods/<code>/<file>`; resolve sang asset bundle qua
  /// `AssetResolver.resolvePeriodCover`.
  final String? coverImageKey;
  final HeritageBackgroundConfigDto backgroundConfig;
  final List<LearningPathEventNodeDto> events;

  const LearningPathChapterDto({
    required this.chapterId,
    this.parentId,
    this.nodeType = PathNodeType.period,
    required this.code,
    required this.title,
    this.description,
    this.startYear,
    this.endYear,
    this.periodLabel,
    required this.sortOrder,
    this.themeKey,
    this.coverImageKey,
    this.backgroundConfig = HeritageBackgroundConfigDto.paperDefault,
    this.events = const [],
  });

  bool get isEra => nodeType.isEra;
  bool get isPeriod => nodeType.isPeriod;
  bool get isPhase => nodeType.isPhase;

  factory LearningPathChapterDto.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'] as List? ?? const [];
    final events =
        rawEvents
            .whereType<Map>()
            .map(
              (e) =>
                  LearningPathEventNodeDto.fromJson(e.cast<String, dynamic>()),
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return LearningPathChapterDto(
      chapterId: json['chapterId'] as String? ?? '',
      parentId: json['parentId'] as String?,
      nodeType: PathNodeType.parse(json['nodeType'] as String?),
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      startYear: (json['startYear'] as num?)?.toInt(),
      endYear: (json['endYear'] as num?)?.toInt(),
      periodLabel: json['periodLabel'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      themeKey: json['themeKey'] as String?,
      coverImageKey: json['coverImageKey'] as String?,
      backgroundConfig: json['backgroundConfig'] is Map
          ? HeritageBackgroundConfigDto.fromJson(
              (json['backgroundConfig'] as Map).cast<String, dynamic>(),
            )
          : HeritageBackgroundConfigDto.paperDefault,
      events: events,
    );
  }

  Map<String, dynamic> toJson() => {
    'chapterId': chapterId,
    'parentId': parentId,
    'nodeType': nodeType.wireValue,
    'code': code,
    'title': title,
    if (description != null) 'description': description,
    if (startYear != null) 'startYear': startYear,
    if (endYear != null) 'endYear': endYear,
    if (periodLabel != null) 'periodLabel': periodLabel,
    'sortOrder': sortOrder,
    if (themeKey != null) 'themeKey': themeKey,
    if (coverImageKey != null) 'coverImageKey': coverImageKey,
    'backgroundConfig': backgroundConfig.toJson(),
    'events': events.map((e) => e.toJson()).toList(),
  };
}


typedef PathChapterDto = LearningPathChapterDto;

/// Nút cây phân cấp `ERA -> PERIOD -> PHASE` phục vụ điều hướng và hiển thị.
class LearningPathChapterTreeNode {
  final LearningPathChapterDto chapter;
  final int depth;
  final List<LearningPathChapterTreeNode> children;
  final int totalSubtreeEvents;

  const LearningPathChapterTreeNode({
    required this.chapter,
    required this.depth,
    required this.children,
    required this.totalSubtreeEvents,
  });

  PathNodeType get nodeType => chapter.nodeType;

  /// Toàn bộ sự kiện trực thuộc nút này và các nút con theo thứ tự cây.
  List<LearningPathEventNodeDto> get allEventsInSubtree {
    final result = <LearningPathEventNodeDto>[...chapter.events];
    for (final child in children) {
      result.addAll(child.allEventsInSubtree);
    }
    return result;
  }
}

/// Nhóm các `PERIOD` theo từng `ERA` (hỗ trợ E2: nhóm theo ERA, ẩn tầng chỉ có 1 mục).
class EraGroupDto {
  /// Nút `ERA` cha (null nếu lộ trình v1 phẳng chỉ có các `PERIOD` gốc).
  final LearningPathChapterDto? era;

  /// Các `PERIOD` thuộc `ERA` này theo thứ tự `sortOrder`.
  final List<LearningPathChapterDto> periods;

  const EraGroupDto({required this.era, required this.periods});

  bool get hasSinglePeriod => periods.length == 1;
}

/// Phản hồi của `POST /api/v1/me/learning-path/periods/{periodCode}/touch`.
class TouchPeriodResponseDto {
  final String periodCode;
  final String chapterId;
  final DateTime? touchedAt;

  const TouchPeriodResponseDto({
    required this.periodCode,
    required this.chapterId,
    this.touchedAt,
  });

  factory TouchPeriodResponseDto.fromJson(Map<String, dynamic> json) {
    final Object? rawTouched = json['touchedAt'];
    DateTime? parsedTouched;
    if (rawTouched is String && rawTouched.isNotEmpty) {
      parsedTouched = DateTime.tryParse(rawTouched);
    }
    return TouchPeriodResponseDto(
      periodCode: json['periodCode'] as String? ?? '',
      chapterId: json['chapterId'] as String? ?? '',
      touchedAt: parsedTouched,
    );
  }

  Map<String, dynamic> toJson() => {
    'periodCode': periodCode,
    'chapterId': chapterId,
    'touchedAt': touchedAt?.toUtc().toIso8601String(),
  };
}

/// DTO toàn diện cho Lộ Trình Học Tập (`GET /api/v1/me/learning-path` và `GET /api/v1/learning-path`).
class LearningPathDto {
  final String pathCode;
  final int pathVersion;
  final String? title;
  final String? description;
  final bool enrolled;
  final LearningPathSummaryDto summary;
  final LearningPathCurrentDto? current;
  final List<LearningPathChapterDto> chapters;
  final List<PeriodProgressDto> periodProgress;
  final Map<String, LearningPathCurrentDto> currentByPeriod;
  final String? lastPeriodCode;

  const LearningPathDto({
    required this.pathCode,
    required this.pathVersion,
    this.title,
    this.description,
    this.enrolled = false,
    this.summary = const LearningPathSummaryDto(),
    this.current,
    this.chapters = const [],
    this.periodProgress = const [],
    this.currentByPeriod = const {},
    this.lastPeriodCode,
  });

  factory LearningPathDto.fromJson(Map<String, dynamic> json) {
    final Object? rawSummary = json['summary'];
    final Object? rawCurrent = json['current'];
    final rawChapters = json['chapters'] as List? ?? const [];
    final rawPeriodProgress = json['periodProgress'] as List? ?? const [];
    final Object? rawCurrentByPeriod = json['currentByPeriod'];

    final Map<String, LearningPathCurrentDto> parsedCurrentByPeriod = {};
    if (rawCurrentByPeriod is Map) {
      for (final entry in rawCurrentByPeriod.entries) {
        final key = entry.key?.toString();
        final val = entry.value;
        if (key != null && key.isNotEmpty && val is Map) {
          parsedCurrentByPeriod[key] = LearningPathCurrentDto.fromJson(
            val.cast<String, dynamic>(),
          );
        }
      }
    }

    return LearningPathDto(
      pathCode: json['pathCode'] as String? ?? defaultLearningPathCode,
      pathVersion: (json['pathVersion'] as num?)?.toInt() ?? 1,
      title: json['title'] as String?,
      description: json['description'] as String?,
      enrolled: json['enrolled'] as bool? ?? false,
      summary: rawSummary is Map
          ? LearningPathSummaryDto.fromJson(rawSummary.cast<String, dynamic>())
          : const LearningPathSummaryDto(),
      current: rawCurrent is Map
          ? LearningPathCurrentDto.fromJson(rawCurrent.cast<String, dynamic>())
          : null,
      chapters: rawChapters
          .whereType<Map>()
          .map(
            (e) => LearningPathChapterDto.fromJson(e.cast<String, dynamic>()),
          )
          .toList(),
      periodProgress: rawPeriodProgress
          .whereType<Map>()
          .map((e) => PeriodProgressDto.fromJson(e.cast<String, dynamic>()))
          .toList(),
      currentByPeriod: parsedCurrentByPeriod,
      lastPeriodCode: json['lastPeriodCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'pathCode': pathCode,
    'pathVersion': pathVersion,
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    'enrolled': enrolled,
    'summary': summary.toJson(),
    'current': current?.toJson(),
    'chapters': chapters.map((c) => c.toJson()).toList(),
    'periodProgress': periodProgress.map((p) => p.toJson()).toList(),
    'currentByPeriod': {
      for (final entry in currentByPeriod.entries)
        entry.key: entry.value.toJson(),
    },
    'lastPeriodCode': lastPeriodCode,
  };

  LearningPathDto copyWith({
    String? pathCode,
    int? pathVersion,
    String? title,
    String? description,
    bool? enrolled,
    LearningPathSummaryDto? summary,
    LearningPathCurrentDto? current,
    List<LearningPathChapterDto>? chapters,
    List<PeriodProgressDto>? periodProgress,
    Map<String, LearningPathCurrentDto>? currentByPeriod,
    String? lastPeriodCode,
  }) {
    return LearningPathDto(
      pathCode: pathCode ?? this.pathCode,
      pathVersion: pathVersion ?? this.pathVersion,
      title: title ?? this.title,
      description: description ?? this.description,
      enrolled: enrolled ?? this.enrolled,
      summary: summary ?? this.summary,
      current: current ?? this.current,
      chapters: chapters ?? this.chapters,
      periodProgress: periodProgress ?? this.periodProgress,
      currentByPeriod: currentByPeriod ?? this.currentByPeriod,
      lastPeriodCode: lastPeriodCode ?? this.lastPeriodCode,
    );
  }

  /// Danh sách các nút gốc `ERA` sắp theo `sortOrder`.
  List<LearningPathChapterDto> get eras {
    final list = chapters.where((c) => c.isEra).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  /// Danh sách tất cả các nút `PERIOD` theo thứ tự cây.
  List<LearningPathChapterDto> get periods {
    return chapters.where((c) => c.isPeriod).toList();
  }

  /// Các `PERIOD` trực thuộc một `ERA` cụ thể.
  List<LearningPathChapterDto> periodsOfEra(String eraChapterId) {
    final list = chapters
        .where((c) => c.isPeriod && c.parentId == eraChapterId)
        .toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  /// Các `PHASE` trực thuộc một `PERIOD` cụ thể.
  List<LearningPathChapterDto> phasesOfPeriod(String periodChapterId) {
    final list = chapters
        .where((c) => c.isPhase && c.parentId == periodChapterId)
        .toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  /// Toàn bộ sự kiện thuộc một `PERIOD` (bao gồm sự kiện gắn trực tiếp vào `PERIOD`
  /// và sự kiện gắn vào các `PHASE` con của `PERIOD`), khớp `LearnerPathProgressionService`.
  List<LearningPathEventNodeDto> eventsOfPeriod(String periodChapterId) {
    final period = chapterById(periodChapterId);
    if (period == null) return const [];
    final result = <LearningPathEventNodeDto>[...period.events];
    for (final phase in phasesOfPeriod(periodChapterId)) {
      result.addAll(phase.events);
    }
    return result;
  }

  /// Toàn bộ sự kiện thuộc `PERIOD` có mã [periodCode].
  List<LearningPathEventNodeDto> eventsOfPeriodCode(String periodCode) {
    final period = periodByCode(periodCode);
    if (period == null) return const [];
    return eventsOfPeriod(period.chapterId);
  }

  /// Dựng cây phân cấp `ERA -> PERIOD -> PHASE` từ danh sách phẳng `chapters`.
  List<LearningPathChapterTreeNode> buildTree() {
    final byId = <String, LearningPathChapterDto>{
      for (final ch in chapters) ch.chapterId: ch,
    };
    final childrenIdsByParent = <String, List<LearningPathChapterDto>>{};
    final rootChapters = <LearningPathChapterDto>[];

    for (final ch in chapters) {
      final pid = ch.parentId;
      if (pid != null && byId.containsKey(pid) && pid != ch.chapterId) {
        childrenIdsByParent.putIfAbsent(pid, () => []).add(ch);
      } else {
        rootChapters.add(ch);
      }
    }

    int compareChapters(LearningPathChapterDto a, LearningPathChapterDto b) {
      final cmp = a.sortOrder.compareTo(b.sortOrder);
      return cmp != 0 ? cmp : a.code.compareTo(b.code);
    }

    rootChapters.sort(compareChapters);
    for (final list in childrenIdsByParent.values) {
      list.sort(compareChapters);
    }

    LearningPathChapterTreeNode buildNode(
      LearningPathChapterDto current,
      int depth,
    ) {
      final rawChildren = childrenIdsByParent[current.chapterId] ?? const [];
      final childNodes = [
        for (final child in rawChildren) buildNode(child, depth + 1),
      ];
      final totalEvents =
          current.events.length +
          childNodes.fold<int>(0, (sum, n) => sum + n.totalSubtreeEvents);
      return LearningPathChapterTreeNode(
        chapter: current,
        depth: depth,
        children: childNodes,
        totalSubtreeEvents: totalEvents,
      );
    }

    return [for (final root in rootChapters) buildNode(root, 0)];
  }

  /// Nhóm các `PERIOD` theo `ERA` để hiển thị trên màn Chọn thời kỳ (E2).
  List<EraGroupDto> get eraGroups {
    final eraList = eras;
    if (eraList.isEmpty) {
      final rootPeriods = periods;
      if (rootPeriods.isEmpty) return const [];
      return [EraGroupDto(era: null, periods: rootPeriods)];
    }
    final groupedIds = <String>{};
    final groups = <EraGroupDto>[];
    for (final era in eraList) {
      final childPeriods = periodsOfEra(era.chapterId);
      for (final p in childPeriods) {
        groupedIds.add(p.chapterId);
      }
      groups.add(EraGroupDto(era: era, periods: childPeriods));
    }
    final ungrouped = periods
        .where((p) => !groupedIds.contains(p.chapterId))
        .toList();
    if (ungrouped.isNotEmpty) {
      groups.add(EraGroupDto(era: null, periods: ungrouped));
    }
    return groups;
  }

  LearningPathChapterDto? chapterById(String? chapterId) {
    if (chapterId == null || chapterId.isEmpty) return null;
    for (final ch in chapters) {
      if (ch.chapterId == chapterId) return ch;
    }
    return null;
  }

  LearningPathChapterDto? chapterByCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final ch in chapters) {
      if (ch.code == code) return ch;
    }
    return null;
  }

  LearningPathChapterDto? periodByCode(String? periodCode) {
    if (periodCode == null || periodCode.isEmpty) return null;
    for (final ch in chapters) {
      if (ch.isPeriod && ch.code == periodCode) return ch;
    }
    return null;
  }

  PeriodProgressDto? progressForPeriod(String? periodCode) {
    if (periodCode == null || periodCode.isEmpty) return null;
    for (final p in periodProgress) {
      if (p.code == periodCode) return p;
    }
    return null;
  }

  LearningPathCurrentDto? currentForPeriod(String? periodCode) {
    if (periodCode == null || periodCode.isEmpty) return null;
    return currentByPeriod[periodCode];
  }

  /// Con trỏ ưu tiên từ `currentByPeriod[lastPeriodCode]`, fallback sang `current`
  /// hoặc thời kỳ đầu tiên đang có bài học mở (phục vụ E3 Trang chủ).
  LearningPathCurrentDto? get effectiveCurrent {
    if (lastPeriodCode != null && lastPeriodCode!.isNotEmpty) {
      final byLast = currentByPeriod[lastPeriodCode!];
      if (byLast != null) return byLast;
    }
    if (current != null) return current;
    for (final val in currentByPeriod.values) {
      return val;
    }
    return null;
  }

  LearningPathEventNodeDto? findEventByNodeId(String? eventNodeId) {
    if (eventNodeId == null || eventNodeId.isEmpty) return null;
    for (final ch in chapters) {
      for (final ev in ch.events) {
        if (ev.eventNodeId == eventNodeId) return ev;
      }
    }
    return null;
  }

  LearningPathEventNodeDto? findEventById(String? eventIdOrSlug) {
    if (eventIdOrSlug == null || eventIdOrSlug.isEmpty) return null;
    for (final ch in chapters) {
      for (final ev in ch.events) {
        if (ev.eventId == eventIdOrSlug || ev.slug == eventIdOrSlug) {
          return ev;
        }
        if (eventIdOrSlug == 'evt_bach_dang_938' &&
            (ev.slug == 'bach-dang-938' ||
                ev.eventId == '00000000-0000-0000-0000-000000000001')) {
          return ev;
        }
      }
    }
    return null;
  }

  LearningPathLessonNodeDto? findLessonById(String? lessonId) {
    if (lessonId == null || lessonId.isEmpty) return null;
    for (final ch in chapters) {
      for (final ev in ch.events) {
        for (final les in ev.lessons) {
          if (les.lessonId == lessonId) return les;
        }
      }
    }
    return null;
  }

  /// Trạng thái của bài học trong lộ trình; trả `null` nếu bài học nằm ngoài lộ trình
  /// (theo A1: bài PUBLISHED ngoài lộ trình được phép học tự do).
  LearnerPathStatus? lessonStatusOf(String? lessonId) {
    return findLessonById(lessonId)?.status;
  }

  /// Ánh xạ `lessonId -> LearnerPathStatus` cho toàn bộ bài học gắn trong lộ trình.
  Map<String, LearnerPathStatus> get lessonStatusMap {
    final map = <String, LearnerPathStatus>{};
    for (final ch in chapters) {
      for (final ev in ch.events) {
        for (final les in ev.lessons) {
          map[les.lessonId] = les.status;
        }
      }
    }
    return map;
  }
}

typedef LearnerLearningPathDto = LearningPathDto;
