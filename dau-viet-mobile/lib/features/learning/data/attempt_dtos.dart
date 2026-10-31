/// DTO attempt lifecycle — khớp LearnerAttemptController records.
/// Mọi trường free-form JSON (config/feedback/result/detail) giữ Map thô.
library;

import '../../energy/data/energy_dto.dart';
import '../../rewards/data/reward_dtos.dart';
import '../../streak/data/streak_dto.dart';

class AttemptProgressDto {
  final int completedRequired;
  final int totalRequired;

  const AttemptProgressDto({
    required this.completedRequired,
    required this.totalRequired,
  });

  factory AttemptProgressDto.fromJson(Map<String, dynamic>? json) =>
      AttemptProgressDto(
        completedRequired: (json?['completedRequired'] as num?)?.toInt() ?? 0,
        totalRequired: (json?['totalRequired'] as num?)?.toInt() ?? 0,
      );

  static const empty = AttemptProgressDto(
    completedRequired: 0,
    totalRequired: 0,
  );

  double get fraction =>
      totalRequired <= 0 ? 0 : completedRequired / totalRequired;
}

/// `completion` verdict — {complete, reason, detail?}.
class CompletionVerdictDto {
  final bool complete;
  final String? reason;
  final Map<String, dynamic>? detail;

  const CompletionVerdictDto({
    required this.complete,
    this.reason,
    this.detail,
  });

  factory CompletionVerdictDto.fromJson(Map<String, dynamic>? json) =>
      CompletionVerdictDto(
        complete: json?['complete'] as bool? ?? false,
        reason: json?['reason'] as String?,
        detail: (json?['detail'] as Map?)?.cast<String, dynamic>(),
      );

  static const unknown = CompletionVerdictDto(complete: false);
}

class AttemptStartDto {
  final String attemptId;
  final String lessonVersionId;
  final String status;
  final bool resumed;
  final String? currentStageId;
  final String? currentActivityId;

  const AttemptStartDto({
    required this.attemptId,
    required this.lessonVersionId,
    required this.status,
    required this.resumed,
    this.currentStageId,
    this.currentActivityId,
  });

  factory AttemptStartDto.fromJson(Map<String, dynamic> json) =>
      AttemptStartDto(
        attemptId: json['attemptId'] as String? ?? '',
        lessonVersionId: json['lessonVersionId'] as String? ?? '',
        status: json['status'] as String? ?? '',
        resumed: json['resumed'] as bool? ?? false,
        currentStageId: json['currentStageId'] as String?,
        currentActivityId: json['currentActivityId'] as String?,
      );
}

class StageRefDto {
  final String id;
  final String? type;
  final String? title;

  const StageRefDto({required this.id, this.type, this.title});

  factory StageRefDto.fromJson(Map<String, dynamic>? json) => StageRefDto(
    id: json?['id'] as String? ?? '',
    type: json?['type'] as String?,
    title: json?['title'] as String?,
  );
}

class ActivityRefDto {
  final String id;
  final String? type;
  final String? instruction;
  final Map<String, dynamic> config;
  final Map<String, dynamic> feedback;

  /// GAME-03 additive: activity này có chấm điểm → submit sai sẽ trừ
  /// Thể lực. Server cũ/mock không trả → false (ẩn hint chi phí).
  final bool graded;

  /// Số Thể lực trừ khi trả lời SAI (clamp ở số dư). Null khi !graded
  /// hoặc server cũ — chỉ dùng để hiển thị hint, không tự suy lại.
  final int? incorrectPenalty;

  // ---- 4-step flow fields (additive, null-safe) ----
  /// Loại dấu vết (CONTEXT/CHARACTERS/DEVELOPMENT/SIGNIFICANCE) — chỉ có
  /// ở activities trong DISCOVERY stage của bài học 4 bước.
  final String? clueType;
  /// Tên hiển thị của dấu vết / hoạt động (admin thay thế mặc định).
  final String? title;
  /// Mô tả ngắn của dấu vết / hoạt động.
  final String? description;
  /// Asset id ảnh đại diện dấu vết (hiển thị trên lưới Bước 1).
  final String? coverAssetId;
  /// Activity đã hoàn thành (dùng để render completed badge ở clue grid).
  final bool completed;

  const ActivityRefDto({
    required this.id,
    this.type,
    this.instruction,
    required this.config,
    required this.feedback,
    this.graded = false,
    this.incorrectPenalty,
    this.clueType,
    this.title,
    this.description,
    this.coverAssetId,
    this.completed = false,
  });

  factory ActivityRefDto.fromJson(Map<String, dynamic>? json) => ActivityRefDto(
    id: json?['id'] as String? ?? '',
    type: json?['type'] as String?,
    instruction: json?['instruction'] as String?,
    config: (json?['config'] as Map?)?.cast<String, dynamic>() ?? const {},
    feedback: (json?['feedback'] as Map?)?.cast<String, dynamic>() ?? const {},
    graded: json?['graded'] as bool? ?? false,
    incorrectPenalty: (json?['incorrectPenalty'] as num?)?.toInt(),
    clueType: json?['clueType'] as String?,
    title: json?['title'] as String?,
    description: json?['description'] as String?,
    coverAssetId: json?['coverAssetId'] as String?,
    completed: json?['completed'] as bool? ?? false,
  );

  /// Số lượt thử tối đa được cấu hình cho activity (auto-graded).
  /// Đọc từ config.maxAttempts; null khi handler không giới hạn.
  int? get maxAttempts => (config['maxAttempts'] as num?)?.toInt();

  /// Resolve feedbackCode → text từ feedback map (key có thể null).
  String? feedbackText(String? code) {
    if (code == null) return null;
    final Object? entry = feedback[code];
    if (entry is String) return entry;
    if (entry is Map) {
      return (entry['text'] ?? entry['message'] ?? entry['body']) as String?;
    }
    return null;
  }
}

/// Trạng thái từng dấu vết trong Bước 1 DISCOVERY của bài học 4 bước.
class ClueStatusDto {
  final String activityId;
  final String? clueType;
  final String? title;
  final String? description;
  final String? coverAssetId;
  final String? activityType;
  final String status;
  final bool completed;

  const ClueStatusDto({
    required this.activityId,
    this.clueType,
    this.title,
    this.description,
    this.coverAssetId,
    this.activityType,
    required this.status,
    required this.completed,
  });

  factory ClueStatusDto.fromJson(Map<String, dynamic>? json) => ClueStatusDto(
    activityId: json?['activityId'] as String? ?? '',
    clueType: json?['clueType'] as String?,
    title: json?['title'] as String?,
    description: json?['description'] as String?,
    coverAssetId: json?['coverAssetId'] as String?,
    activityType: json?['activityType'] as String?,
    status: json?['status'] as String? ?? 'NOT_STARTED',
    completed: json?['completed'] as bool? ?? false,
  );
}

/// Tiến độ từng bước trong bài học 4 bước — null khi backend chưa hỗ trợ.
class StepProgressDto {
  final int discoveryCompleted;
  final int discoveryTotal;
  final bool hypothesisCompleted;
  final bool verificationCompleted;
  final bool reconstructionCompleted;
  final int currentStepNumber;
  final List<ClueStatusDto> clues;

  const StepProgressDto({
    required this.discoveryCompleted,
    required this.discoveryTotal,
    required this.hypothesisCompleted,
    required this.verificationCompleted,
    required this.reconstructionCompleted,
    required this.currentStepNumber,
    required this.clues,
  });

  factory StepProgressDto.fromJson(Map<String, dynamic>? json) =>
      StepProgressDto(
        discoveryCompleted:
            (json?['discoveryCompleted'] as num?)?.toInt() ?? 0,
        discoveryTotal: (json?['discoveryTotal'] as num?)?.toInt() ?? 0,
        hypothesisCompleted: json?['hypothesisCompleted'] as bool? ?? false,
        verificationCompleted:
            json?['verificationCompleted'] as bool? ?? false,
        reconstructionCompleted:
            json?['reconstructionCompleted'] as bool? ?? false,
        currentStepNumber: (json?['currentStepNumber'] as num?)?.toInt() ?? 1,
        clues: (json?['clues'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => ClueStatusDto.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

  /// true khi đây là bài học 4 bước (có dữ liệu dấu vết).
  bool get isFourStep => discoveryTotal > 0 && clues.isNotEmpty;

  /// true khi đang ở Bước 1 và chưa hết dấu vết — render lưới chọn.
  bool get shouldShowGrid =>
      isFourStep &&
      !hypothesisCompleted &&
      discoveryCompleted < discoveryTotal;
}

/// GET /attempts/{id}/current — activity null khi hết required.
class CurrentActivityDto {
  final StageRefDto? stage;
  final ActivityRefDto? activity;
  final AttemptProgressDto progress;

  /// 4-step flow additive: tiến độ từng bước — null trên server cũ.
  final StepProgressDto? stepProgress;

  const CurrentActivityDto({
    this.stage,
    this.activity,
    required this.progress,
    this.stepProgress,
  });

  factory CurrentActivityDto.fromJson(Map<String, dynamic> json) =>
      CurrentActivityDto(
        stage: json['stage'] == null
            ? null
            : StageRefDto.fromJson(
                (json['stage'] as Map).cast<String, dynamic>(),
              ),
        activity: json['activity'] == null
            ? null
            : ActivityRefDto.fromJson(
                (json['activity'] as Map).cast<String, dynamic>(),
              ),
        progress: AttemptProgressDto.fromJson(
          (json['progress'] as Map?)?.cast<String, dynamic>(),
        ),
        stepProgress: json['stepProgress'] is Map
            ? StepProgressDto.fromJson(
                (json['stepProgress'] as Map).cast<String, dynamic>(),
              )
            : null,
      );

  /// true khi đây là bài học 4 bước và đang ở DISCOVERY stage.
  bool get isDiscoveryStep =>
      stepProgress?.isFourStep == true &&
      (stage?.type?.toUpperCase() == 'DISCOVERY');
}

/// evaluation {outcome, completed, output, feedbackCode}.
class EvaluationDto {
  final String? outcome;
  final bool completed;
  final Map<String, dynamic>? output;
  final String? feedbackCode;
  final int? _correctPositions;
  final int? _totalItems;

  const EvaluationDto({
    this.outcome,
    required this.completed,
    this.output,
    this.feedbackCode,
    int? correctPositions,
    int? totalItems,
  }) :
       // ignore: prefer_initializing_formals
       _correctPositions = correctPositions,
       // ignore: prefer_initializing_formals
       _totalItems = totalItems;

  factory EvaluationDto.fromJson(Map<String, dynamic>? json) {
    final out = (json?['output'] as Map?)?.cast<String, dynamic>();
    final src = out ?? json ?? const <String, dynamic>{};
    return EvaluationDto(
      outcome: json?['outcome'] as String?,
      completed: json?['completed'] as bool? ?? false,
      output: out,
      feedbackCode: json?['feedbackCode'] as String?,
      correctPositions:
          (json?['correctPositions'] as num?)?.toInt() ??
          (json?['correctCount'] as num?)?.toInt() ??
          (src['correctPositions'] as num?)?.toInt() ??
          (src['correctCount'] as num?)?.toInt(),
      totalItems:
          (json?['totalItems'] as num?)?.toInt() ??
          (json?['expectedCount'] as num?)?.toInt() ??
          (src['totalItems'] as num?)?.toInt() ??
          (src['expectedCount'] as num?)?.toInt(),
    );
  }

  /// Số vị trí/cặp/phần đã đúng (DRAG_ORDER, MATCHING, CER_CHOICE, EVIDENCE_SELECT…).
  int? get correctPositions =>
      _correctPositions ??
      (output?['correctPositions'] as num?)?.toInt() ??
      (output?['correctCount'] as num?)?.toInt();

  /// Tổng số mục cần đúng.
  int? get totalItems =>
      _totalItems ??
      (output?['totalItems'] as num?)?.toInt() ??
      (output?['expectedCount'] as num?)?.toInt();
  /// Lượt thử đã dùng (1-based theo submit hiện tại).
  int? get attemptCount => (output?['attemptCount'] as num?)?.toInt();

  /// Đã hết ngân sách lượt thử — server hoàn tất tiến độ.
  bool get exhausted => output?['exhausted'] == true;

  /// Số cặp ghép đúng (MATCHING) — alias ngắn gọn của correctPositions.
  int? get matchedCount => (output?['matchedCount'] as num?)?.toInt();

  /// Số phần CER đúng (0..3).
  int? get partsCorrect => (output?['partsCorrect'] as num?)?.toInt();


  /// Điểm phần trăm (0..1) cho các activity chấm điểm theo F1 / partial credit.
  double? get score => (output?['score'] as num?)?.toDouble();

  /// Số bằng chứng chọn đúng trong lượt nộp (EVIDENCE_SELECT graded).
  int? get correctCount => (output?['correctCount'] as num?)?.toInt();

  /// Số bằng chứng chọn thừa/sai trong lượt nộp (EVIDENCE_SELECT graded).
  int? get falseCount => (output?['falseCount'] as num?)?.toInt();

  /// Đã cạn cả ngân sách lượt chấm lẫn lượt remedial (Policy B).
  bool get budgetExhausted => output?['budgetExhausted'] == true;

  /// Verdict đúng/sai cho từng bằng chứng học viên ĐÃ CHỌN (không chứa đáp án bị bỏ sót).
  Map<String, String> get selectedVerdicts {
    final raw = output?['selectedVerdicts'];
    if (raw is! Map) return const {};
    final result = <String, String>{};
    raw.forEach((k, v) {
      if (k is String && v is String) {
        result[k] = v;
      }
    });
    return result;
  }
  /// Verdict kiểm chứng (SUPPORTED/PARTIAL/CONTRADICTED) — lấy từ
  /// output.verification, fallback outcome khi handler nhét vào outcome.
  String? get verificationVerdict =>
      (output?['verification'] as String?) ?? outcome;
}

/// next {stageId, activityId, activityType, learnerConfig}.
class NextRefDto {
  final String? stageId;
  final String? activityId;
  final String? activityType;
  final Map<String, dynamic>? learnerConfig;

  const NextRefDto({
    this.stageId,
    this.activityId,
    this.activityType,
    this.learnerConfig,
  });

  factory NextRefDto.fromJson(Map<String, dynamic>? json) => NextRefDto(
    stageId: json?['stageId'] as String?,
    activityId: json?['activityId'] as String?,
    activityType: json?['activityType'] as String?,
    learnerConfig: (json?['learnerConfig'] as Map?)?.cast<String, dynamic>(),
  );
}

class SubmitResultDto {
  final String status;
  final EvaluationDto evaluation;
  final bool activityCompleted;
  final AttemptProgressDto progress;
  final NextRefDto? next;
  final CompletionVerdictDto completion;

  /// GAME-03 (additive): số Thể lực server đã trừ cho submission này
  /// (0 khi ungraded/PARTIAL/flag tắt; có thể < penalty khi clamp ở 0).
  /// KHÔNG suy balance mới = old - deducted — server có thể lazy-recover
  /// trước khi trừ; dùng [energy] để biết balance authoritative.
  final int energyDeducted;

  /// GAME-03 (additive): snapshot Thể lực SAU submit — balance authoritative.
  /// Null trên server version cũ / mock → caller fallback refresh GET.
  final EnergyStateDto? energy;

  const SubmitResultDto({
    required this.status,
    required this.evaluation,
    required this.activityCompleted,
    required this.progress,
    this.next,
    required this.completion,
    this.energyDeducted = 0,
    this.energy,
  });

  factory SubmitResultDto.fromJson(Map<String, dynamic> json) =>
      SubmitResultDto(
        status: json['status'] as String? ?? '',
        evaluation: EvaluationDto.fromJson(
          (json['evaluation'] as Map?)?.cast<String, dynamic>(),
        ),
        activityCompleted: json['activityCompleted'] as bool? ?? false,
        progress: AttemptProgressDto.fromJson(
          (json['progress'] as Map?)?.cast<String, dynamic>(),
        ),
        next: json['next'] == null
            ? null
            : NextRefDto.fromJson(
                (json['next'] as Map).cast<String, dynamic>(),
              ),
        completion: CompletionVerdictDto.fromJson(
          (json['completion'] as Map?)?.cast<String, dynamic>(),
        ),
        energyDeducted: (json['energyDeducted'] as num?)?.toInt() ?? 0,
        energy: json['energy'] is Map
            ? EnergyStateDto.fromJson(
                (json['energy'] as Map).cast<String, dynamic>(),
              )
            : null,
      );
}

/// MAP-V2 (A3/C2/E5): Thông tin địa điểm di tích vừa mở khóa trong lượt
/// hoàn thành bài học (`CompleteAttemptResponse.UnlockedLocationCue`).
class UnlockedLocationCueDto {
  final String locationId;
  final String? slug;
  final String title;
  final String? kind;
  final String? coverAssetId;

  const UnlockedLocationCueDto({
    required this.locationId,
    this.slug,
    required this.title,
    this.kind,
    this.coverAssetId,
  });

  factory UnlockedLocationCueDto.fromJson(Map<String, dynamic> json) =>
      UnlockedLocationCueDto(
        locationId: (json['locationId'] ?? json['id'])?.toString().trim() ?? '',
        slug: (json['slug'] as String?)?.trim(),
        title: (json['title'] as String?)?.trim() ?? '',
        kind: (json['kind'] as String?)?.trim(),
        coverAssetId: (json['coverAssetId'] as String?)?.trim(),
      );

  Map<String, dynamic> toJson() => {
    'locationId': locationId,
    if (slug != null) 'slug': slug,
    'title': title,
    if (kind != null) 'kind': kind,
    if (coverAssetId != null) 'coverAssetId': coverAssetId,
  };

  /// Nhãn tiếng Việt cho phân loại địa điểm di sản (`kind`).
  String get kindLabelVi {
    switch (kind?.toUpperCase()) {
      case 'HERITAGE_SITE':
        return 'Di tích lịch sử';
      case 'BATTLEFIELD':
        return 'Chiến trường cổ';
      case 'ANCIENT_CAPITAL':
        return 'Kinh đô cổ';
      case 'ARCHAEOLOGICAL_SITE':
        return 'Di chỉ khảo cổ';
      case 'MEMORIAL':
        return 'Khu tưởng niệm';
      case 'SCHEMATIC_REGION':
        return 'Vùng chiến lược';
      default:
        return 'Địa điểm di sản';
    }
  }
}

class CompleteResultDto {
  final String attemptId;
  final String status;
  final bool alreadyCompleted;
  final String? completedAt;
  final CompletionVerdictDto completion;
  final AttemptProgressDto progress;

  /// GAME-04 additive: dossier ids mở MỚI trong lần complete này — rỗng
  /// khi replay/đã grant. Client hiện cue một lần, không re-show.
  final List<String> newlyUnlockedDossiers;

  /// STREAK-01 additive: thông tin Chuỗi Ngày Học — chỉ non-null khi
  /// server công nhận một ngày học MỚI (điều kiện phát animation ngọn
  /// lửa tăng ở LessonResultScreen). Null khi replay/ngày đã tính.
  final StreakInfoDto? streak;

  /// MAP-V2 (E5) additive: các địa điểm di sản vừa mở khóa MỚI trong
  /// transaction complete này — rỗng khi replay (`alreadyCompleted=true`).
  final List<UnlockedLocationCueDto> newlyUnlockedLocations;

  const CompleteResultDto({
    required this.attemptId,
    required this.status,
    required this.alreadyCompleted,
    this.completedAt,
    required this.completion,
    required this.progress,
    this.newlyUnlockedDossiers = const [],
    this.streak,
    this.newlyUnlockedLocations = const [],
  });

  factory CompleteResultDto.fromJson(
    Map<String, dynamic> json,
  ) => CompleteResultDto(
    attemptId: json['attemptId'] as String? ?? '',
    status: json['status'] as String? ?? '',
    alreadyCompleted: json['alreadyCompleted'] as bool? ?? false,
    completedAt: json['completedAt'] as String?,
    completion: CompletionVerdictDto.fromJson(
      (json['completion'] as Map?)?.cast<String, dynamic>(),
    ),
    progress: AttemptProgressDto.fromJson(
      (json['progress'] as Map?)?.cast<String, dynamic>(),
    ),
    newlyUnlockedDossiers: (json['newlyUnlockedDossiers'] as List? ?? const [])
        .whereType<String>()
        .toList(),
    streak: StreakInfoDto.tryParse(json['streak']),
    newlyUnlockedLocations:
        (json['newlyUnlockedLocations'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (e) => UnlockedLocationCueDto.fromJson(e.cast<String, dynamic>()),
            )
            .toList(),
  );
}

class LessonResultDto {
  final String attemptId;
  final String lessonVersionId;
  final String status;
  final double? score;
  final Map<String, dynamic> result;
  final String? completedAt;
  final String? startedAt;

  /// TASK-0023 (additive): bút toán thưởng CHÍNH attempt này đã kích hoạt
  /// — server đã ghi ledger trong transaction complete(), client chỉ
  /// hiển thị, tuyệt đối không POST lần hai để "nhận" thưởng.
  final List<RewardTransactionDto> rewards;

  /// Vật phẩm mở khóa được ghi nhận bởi attempt này (source_attempt_id).
  final List<InventoryItemDto> itemsUnlocked;

  /// GAME-04 additive: dossier ids mở MỚI trong lần complete này (đọc từ
  /// top-level `newlyUnlockedDossiers` hoặc fallback `result.unlockedDossiers`).
  final List<String> newlyUnlockedDossiers;

  /// STREAK-01 (client-only): ngày học MỚI được công nhận trong lần
  /// complete này — LessonPlayerScreen gắn vào enriched DTO truyền qua
  /// route extra; server KHÔNG trả field này trong GET /result (deep-link
  /// /reload không phát lại animation). Null = không phát animation.
  final StreakInfoDto? newlyRecordedStreak;

  /// MAP-V2 (E5): các địa điểm di sản vừa mở khóa MỚI trong lần complete
  /// này (đọc từ top-level `newlyUnlockedLocations` hoặc fallback
  /// `result.unlockedLocations`).
  final List<UnlockedLocationCueDto> newlyUnlockedLocations;

  const LessonResultDto({
    required this.attemptId,
    required this.lessonVersionId,
    required this.status,
    this.score,
    required this.result,
    this.completedAt,
    this.startedAt,
    this.rewards = const [],
    this.itemsUnlocked = const [],
    this.newlyUnlockedDossiers = const [],
    this.newlyRecordedStreak,
    this.newlyUnlockedLocations = const [],
  });

  factory LessonResultDto.fromJson(Map<String, dynamic> json) {
    final resultMap =
        (json['result'] as Map?)?.cast<String, dynamic>() ?? const {};
    final Object? rawDossiers =
        (json['newlyUnlockedDossiers'] is List &&
            (json['newlyUnlockedDossiers'] as List).isNotEmpty)
        ? json['newlyUnlockedDossiers']
        : (resultMap['unlockedDossiers'] ?? resultMap['newlyUnlockedDossiers']);
    final Object? rawLocations =
        (json['newlyUnlockedLocations'] is List &&
            (json['newlyUnlockedLocations'] as List).isNotEmpty)
        ? json['newlyUnlockedLocations']
        : (resultMap['unlockedLocations'] ??
              resultMap['newlyUnlockedLocations']);
    return LessonResultDto(
      attemptId: json['attemptId'] as String? ?? '',
      lessonVersionId: json['lessonVersionId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble(),
      result: resultMap,
      completedAt: json['completedAt'] as String?,
      startedAt: json['startedAt'] as String?,
      rewards: (json['rewards'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => RewardTransactionDto.fromJson(e.cast<String, dynamic>()))
          .toList(),
      itemsUnlocked: (json['itemsUnlocked'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => InventoryItemDto.fromJson(e.cast<String, dynamic>()))
          .toList(),
      newlyUnlockedDossiers: (rawDossiers is List ? rawDossiers : const [])
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      newlyUnlockedLocations: (rawLocations is List ? rawLocations : const [])
          .whereType<Map>()
          .map(
            (e) => UnlockedLocationCueDto.fromJson(e.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

class AttemptSummaryDto {
  final String attemptId;
  final String? lessonId;
  final String lessonVersionId;
  final String status;
  final String? currentStageId;
  final String? currentActivityId;
  final AttemptProgressDto progress;
  final String? startedAt;
  final String? lastActiveAt;
  final String? completedAt;

  const AttemptSummaryDto({
    required this.attemptId,
    this.lessonId,
    required this.lessonVersionId,
    required this.status,
    this.currentStageId,
    this.currentActivityId,
    required this.progress,
    this.startedAt,
    this.lastActiveAt,
    this.completedAt,
  });

  factory AttemptSummaryDto.fromJson(Map<String, dynamic> json) =>
      AttemptSummaryDto(
        attemptId: json['attemptId'] as String? ?? '',
        lessonId: json['lessonId'] as String?,
        lessonVersionId: json['lessonVersionId'] as String? ?? '',
        status: json['status'] as String? ?? '',
        currentStageId: json['currentStageId'] as String?,
        currentActivityId: json['currentActivityId'] as String?,
        progress: AttemptProgressDto.fromJson(
          (json['progress'] as Map?)?.cast<String, dynamic>(),
        ),
        startedAt: json['startedAt'] as String?,
        lastActiveAt: json['lastActiveAt'] as String?,
        completedAt: json['completedAt'] as String?,
      );
}

class MyProgressDto {
  final List<AttemptSummaryDto> inProgress;
  final int completedCount;

  const MyProgressDto({required this.inProgress, required this.completedCount});

  factory MyProgressDto.fromJson(Map<String, dynamic> json) => MyProgressDto(
    inProgress: (json['inProgress'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => AttemptSummaryDto.fromJson(e.cast<String, dynamic>()))
        .toList(),
    completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
  );
}
