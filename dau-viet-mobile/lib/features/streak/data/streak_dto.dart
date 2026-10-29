/// DTO trạng thái Chuỗi Ngày Học — Ngọn Lửa Hào Khí (STREAK-01).
/// Khớp LearningStreakResponse phía backend (`GET /api/v1/me/streak`).
/// Server là nguồn duy nhất cho mọi con số — client không tự suy.
class LearningStreakDto {
  /// Chuỗi ngày liên tiếp hiện tại (0 = mới/chưa học).
  final int currentStreak;

  /// Kỷ lục chuỗi dài nhất từng đạt — không bao giờ giảm.
  final int longestStreak;

  /// Đã hoàn thành mục tiêu hôm nay chưa (theo giờ server VN).
  final bool completedToday;

  /// Chuỗi còn duy trì được (học hôm qua nhưng chưa hôm nay = true).
  final bool streakAlive;

  /// Ngày VN gần nhất được công nhận — null khi chưa từng học.
  final DateTime? lastQualifiedDate;

  /// Ngày VN hiện tại theo server.
  final DateTime? today;

  /// Timezone server dùng để tính ngày — luôn "Asia/Ho_Chi_Minh".
  final String timezone;

  /// Thời điểm server tại lúc trả response — debug/audit.
  final DateTime? serverTime;

  /// Số Khiên Bảo Vệ đang tích trữ (0..maxShields) — STREAK-02.
  final int shieldCount;

  /// Giới hạn khiên — server trả (3 ở V51); client không hard-code.
  final int maxShields;

  /// Giá đổi một khiên — Điểm Sử Ký.
  final int shieldCostPoints;

  /// Chuỗi có nguy cơ đứt nếu hôm nay không học (last == today-1).
  final bool atRiskToday;

  /// Khiên sẽ tự cứu nếu hôm nay bỏ lỡ đúng 1 ngày.
  final bool shieldWillProtectToday;

  /// Bảng mốc thưởng tĩnh 3/7/14/30 do server trả.
  final List<StreakMilestoneDto> milestones;

  const LearningStreakDto({
    required this.currentStreak,
    required this.longestStreak,
    required this.completedToday,
    required this.streakAlive,
    this.lastQualifiedDate,
    this.today,
    this.timezone = 'Asia/Ho_Chi_Minh',
    this.serverTime,
    this.shieldCount = 0,
    this.maxShields = 3,
    this.shieldCostPoints = 20,
    this.atRiskToday = false,
    this.shieldWillProtectToday = false,
    this.milestones = const [],
  });

  factory LearningStreakDto.fromJson(Map<String, dynamic> json) {
    return LearningStreakDto(
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      completedToday: json['completedToday'] as bool? ?? false,
      streakAlive: json['streakAlive'] as bool? ?? false,
      lastQualifiedDate: _parseDate(json['lastQualifiedDate']),
      today: _parseDate(json['today']),
      timezone: json['timezone'] as String? ?? 'Asia/Ho_Chi_Minh',
      serverTime: _parseInstant(json['serverTime']),
      shieldCount: (json['shieldCount'] as num?)?.toInt() ?? 0,
      maxShields: (json['maxShields'] as num?)?.toInt() ?? 3,
      shieldCostPoints: (json['shieldCostPoints'] as num?)?.toInt() ?? 20,
      atRiskToday: json['atRiskToday'] as bool? ?? false,
      shieldWillProtectToday:
          json['shieldWillProtectToday'] as bool? ?? false,
      milestones: ((json['milestones'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StreakMilestoneDto.fromJson)
          .toList(growable: false),
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static DateTime? _parseInstant(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

/// DTO `GET /api/v1/me/streak/calendar` — danh sách ngày đã học trong
/// khoảng [from, to] mà client đã yêu cầu.
class LearningStreakCalendarDto {
  final DateTime? from;
  final DateTime? to;
  final String timezone;

  /// Các ngày đã hoàn thành ≥1 bài — server sort ASC rồi.
  final List<DateTime> days;

  /// Ngày được Khiên Bảo Vệ cứu (SHIELD_PROTECTED) — tập con của [days],
  /// render marker 🛡️ khác ngày học 🔥 (STREAK-02).
  final List<DateTime> protectedDates;

  final DateTime? serverTime;

  const LearningStreakCalendarDto({
    this.from,
    this.to,
    this.timezone = 'Asia/Ho_Chi_Minh',
    required this.days,
    this.protectedDates = const [],
    this.serverTime,
  });

  factory LearningStreakCalendarDto.fromJson(Map<String, dynamic> json) {
    return LearningStreakCalendarDto(
      from: LearningStreakDto._parseDate(json['from']),
      to: LearningStreakDto._parseDate(json['to']),
      timezone: json['timezone'] as String? ?? 'Asia/Ho_Chi_Minh',
      days: ((json['days'] as List?) ?? const [])
          .map((d) => DateTime.parse(d as String))
          .toList(growable: false),
      protectedDates: ((json['protectedDates'] as List?) ?? const [])
          .map((d) => DateTime.parse(d as String))
          .toList(growable: false),
      serverTime: LearningStreakDto._parseInstant(json['serverTime']),
    );
  }
}

/// Thông tin streak trả kèm `POST /attempts/{id}/complete` — chỉ non-null
/// khi ngày học được công nhận mới (điều kiện chạy animation ngọn lửa
/// tăng ở LessonResultScreen). `null` = ngày đã có → không phát lại.
class StreakInfoDto {
  final bool dayRecorded;
  final int currentStreak;
  final int longestStreak;
  final DateTime? studyDate;

  /// Đồng hồ server lúc ghi ngày học — mốc freshness thật, client KHÔNG
  /// bịa từ DateTime.now() (clock skew không làm sai thứ tự).
  final DateTime? serverTime;

  /// Khiên Bảo Vệ vừa tự trừ để cứu chuỗi (bỏ lỡ đúng 1 ngày) — STREAK-02.
  final bool shieldConsumed;

  /// Số khiên còn lại sau ghi — cập nhật card 🛡️ ngay.
  final int shieldCount;

  /// EXP thưởng chuỗi vừa nhận trong lần complete này.
  final int bonusExp;

  /// Điểm Sử Ký thưởng chuỗi vừa nhận.
  final int bonusPoints;

  /// Mốc chuỗi đạt (3/7/14/30) nếu có; null = không mốc.
  final int? milestoneDay;

  const StreakInfoDto({
    required this.dayRecorded,
    required this.currentStreak,
    required this.longestStreak,
    this.studyDate,
    this.serverTime,
    this.shieldConsumed = false,
    this.shieldCount = 0,
    this.bonusExp = 0,
    this.bonusPoints = 0,
    this.milestoneDay,
  });

  factory StreakInfoDto.fromJson(Map<String, dynamic> json) {
    return StreakInfoDto(
      dayRecorded: json['dayRecorded'] as bool? ?? false,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      studyDate: LearningStreakDto._parseDate(json['studyDate']),
      serverTime: LearningStreakDto._parseInstant(json['serverTime']),
      shieldConsumed: json['shieldConsumed'] as bool? ?? false,
      shieldCount: (json['shieldCount'] as num?)?.toInt() ?? 0,
      bonusExp: (json['bonusExp'] as num?)?.toInt() ?? 0,
      bonusPoints: (json['bonusPoints'] as num?)?.toInt() ?? 0,
      milestoneDay: (json['milestoneDay'] as num?)?.toInt(),
    );
  }

  /// Parse từ `streak` field trong CompleteAttemptResponse — null khi
  /// server không trả (replay / ngày đã tính / không có streak feature).
  static StreakInfoDto? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final dto = StreakInfoDto.fromJson(raw);
    return dto.dayRecorded ? dto : null;
  }
}

/// Một mốc thưởng chuỗi ngày học (STREAK-02) — server trả bảng tĩnh
/// 3/7/14/30 để client render card tiến độ không hard-code.
class StreakMilestoneDto {
  /// current_streak đạt mốc này thì bonus kích hoạt.
  final int day;

  /// EXP bonus CỘNG THÊM trên thưởng duy trì tại mốc.
  final int bonusExp;

  /// Điểm Sử Ký bonus CỘNG THÊM trên thưởng duy trì tại mốc.
  final int bonusPoints;

  const StreakMilestoneDto({
    required this.day,
    required this.bonusExp,
    required this.bonusPoints,
  });

  factory StreakMilestoneDto.fromJson(Map<String, dynamic> json) {
    return StreakMilestoneDto(
      day: (json['day'] as num?)?.toInt() ?? 0,
      bonusExp: (json['bonusExp'] as num?)?.toInt() ?? 0,
      bonusPoints: (json['bonusPoints'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Response của POST /api/v1/me/streak/shields (STREAK-02) — kết quả đổi
/// 20 Điểm Sử Ký lấy 1 Khiên Bảo Vệ Chuỗi.
class StreakShieldPurchaseDto {
  /// Số khiên sau khi mua (1..maxShields).
  final int shieldCount;

  /// Giới hạn tích trữ — 3 ở V51.
  final int maxShields;

  /// Giá đã trả — Điểm Sử Ký.
  final int costPoints;

  /// Số dư ví sau debit — UI render lại pill Điểm Sử Ký ngay.
  final int balanceAfter;

  /// Đồng hồ server lúc ghi — mốc freshness.
  final DateTime? serverTime;

  const StreakShieldPurchaseDto({
    required this.shieldCount,
    required this.maxShields,
    required this.costPoints,
    required this.balanceAfter,
    this.serverTime,
  });

  factory StreakShieldPurchaseDto.fromJson(Map<String, dynamic> json) {
    return StreakShieldPurchaseDto(
      shieldCount: (json['shieldCount'] as num?)?.toInt() ?? 0,
      maxShields: (json['maxShields'] as num?)?.toInt() ?? 3,
      costPoints: (json['costPoints'] as num?)?.toInt() ?? 20,
      balanceAfter: (json['balanceAfter'] as num?)?.toInt() ?? 0,
      serverTime: LearningStreakDto._parseInstant(json['serverTime']),
    );
  }
}
