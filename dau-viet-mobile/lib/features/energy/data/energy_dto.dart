/// Đồng hồ đơn điệu dùng chung — elapsed-micros kể từ lúc process start.
/// Test override bằng [debugOverrideEnergyClock].
int _stopwatchNowMicros() => _sharedStopwatch.elapsedMicroseconds;
final Stopwatch _sharedStopwatch = Stopwatch()..start();

/// Cho phép test ép mốc "đã trôi" tuyệt đối thay vì đếm từ lúc tạo DTO.
/// Chỉ dùng trong test — production luôn null.
int Function()? _testElapsedMicrosOverride;

/// Test-only: cài đồng hồ giả. Trả hàm gỡ.
void Function() debugOverrideEnergyClock(int Function() micros) {
  _testElapsedMicrosOverride = micros;
  return () => _testElapsedMicrosOverride = null;
}

/// DTO trạng thái Thể lực (GAME-03) — khớp EnergyStateResponse phía backend
/// (`GET /api/v1/me/energy` và trường `energy` trong SubmitActivityResponse).
///
/// Server là nguồn duy nhất: client KHÔNG suy balance từ `energyDeducted`
/// (server có thể lazy-recover trước submit) — luôn dùng snapshot này.
///
/// Countdown (FIX-2): khi parse, ghi nhận `_elapsedAtParse` = elapsed của
/// đồng hồ đơn điệu + `serverNowAtParse` = serverTime (hoặc device lúc parse).
/// `timeUntilNextRecovery()` = nextRecoveryAt − (serverNowAtParse + elapsed
/// trôi qua). Không phụ thuộc DateTime.now() tại thời điểm đọc → countdown
/// giảm thật, skew đã bù một lần duy nhất lúc parse.
class EnergyStateDto {
  final int current;
  final int max;
  final int recoveryAmount;
  final int recoveryIntervalSeconds;

  /// Mốc hồi kế tiếp theo đồng hồ server — null khi đã đầy.
  final DateTime? nextRecoveryAt;

  /// Đồng hồ server tại thời điểm trả response — dùng để bù skew.
  final DateTime? serverTime;

  /// Server đã kiểm gate: true = còn đủ Thể lực cho submission được chấm.
  /// Khi backend flag tắt thì luôn true (không phạt/không chặn).
  final bool canSubmitGraded;

  /// "Bây giờ theo server" chốt tại lúc nhận response.
  final DateTime _serverNowAtParse;

  /// Đồng hồ thiết bị lúc parse — chỉ để suy ra offset một lần, KHÔNG
  /// dùng cho countdown (countdown đi qua đồng hồ đơn điệu).
  final DateTime _deviceNowAtParse;

  /// Elapsed-micros của đồng hồ đơn điệu tại lúc nhận response.
  final int _elapsedAtParse;

  EnergyStateDto({
    required this.current,
    required this.max,
    this.recoveryAmount = 0,
    this.recoveryIntervalSeconds = 0,
    this.nextRecoveryAt,
    this.serverTime,
    this.canSubmitGraded = true,
  }) : _deviceNowAtParse = DateTime.now().toUtc(),
       _serverNowAtParse = serverTime ?? DateTime.now().toUtc(),
       _elapsedAtParse = (_testElapsedMicrosOverride ?? _stopwatchNowMicros)();

  factory EnergyStateDto.fromJson(Map<String, dynamic> json) {
    return EnergyStateDto(
      current: (json['current'] as num?)?.toInt() ?? 0,
      max: (json['max'] as num?)?.toInt() ?? 0,
      recoveryAmount: (json['recoveryAmount'] as num?)?.toInt() ?? 0,
      recoveryIntervalSeconds:
          (json['recoveryIntervalSeconds'] as num?)?.toInt() ?? 0,
      nextRecoveryAt: _parseInstant(json['nextRecoveryAt']),
      serverTime: _parseInstant(json['serverTime']),
      canSubmitGraded: json['canSubmitGraded'] as bool? ?? true,
    );
  }

  static DateTime? _parseInstant(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// "Bây giờ theo server" tại thời điểm gọi — mốc parse + thời gian
  /// đơn điệu đã trôi. Không đọc lại DateTime.now() → không đứng yên,
  /// không lệ thuộc tuyệt đối đồng hồ máy (chỉ dùng đồng hồ máy làm
  /// fallback một lần lúc parse khi server không trả serverTime).
  DateTime get serverNow {
    final int elapsedMicros =
        (_testElapsedMicrosOverride ?? _stopwatchNowMicros)() - _elapsedAtParse;
    return _serverNowAtParse.add(Duration(microseconds: elapsedMicros));
  }

  /// Mốc "độ mới" theo server tại lúc response được tạo — stamp bất biến
  /// dùng để so snapshot/GET trong provider (FIX-3). = serverTime khi có,
  /// deviceNow-lúc-parse khi không.
  DateTime get createdAt => _serverNowAtParse;

  /// Offset đồng hồ: serverTime − deviceNow lúc parse (bất biến — chốt
  /// một lần, không tính động). Null khi server không trả serverTime.
  Duration? get serverOffset => serverTime?.difference(_deviceNowAtParse);

  /// Thời lượng còn lại tới mốc hồi — giảm thực sự theo đồng hồ đơn điệu.
  /// Trả null khi không có mốc (đầy). Không bao giờ âm.
  Duration? timeUntilNextRecovery() {
    final next = nextRecoveryAt;
    if (next == null) return null;
    final Duration remain = next.difference(serverNow);
    return remain.isNegative ? Duration.zero : remain;
  }

  double get fraction => max <= 0 ? 0 : (current / max).clamp(0.0, 1.0);
  bool get isFull => current >= max;
  bool get isDepleted => current <= 0;

  /// Chu kỳ hồi dạng phút để hiển thị ("+5 Thể lực mỗi 15 phút").
  int get recoveryIntervalMinutes => recoveryIntervalSeconds ~/ 60;
}
