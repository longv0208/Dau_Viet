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

  const LearningStreakDto({
    required this.currentStreak,
    required this.longestStreak,
    required this.completedToday,
    required this.streakAlive,
    this.lastQualifiedDate,
    this.today,
    this.timezone = 'Asia/Ho_Chi_Minh',
    this.serverTime,
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

  final DateTime? serverTime;

  const LearningStreakCalendarDto({
    this.from,
    this.to,
    this.timezone = 'Asia/Ho_Chi_Minh',
    required this.days,
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

  const StreakInfoDto({
    required this.dayRecorded,
    required this.currentStreak,
    required this.longestStreak,
    this.studyDate,
  });

  factory StreakInfoDto.fromJson(Map<String, dynamic> json) {
    return StreakInfoDto(
      dayRecorded: json['dayRecorded'] as bool? ?? false,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      studyDate: LearningStreakDto._parseDate(json['studyDate']),
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
