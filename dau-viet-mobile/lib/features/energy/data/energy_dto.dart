/// DTO trạng thái Thể lực (GAME-03) — khớp EnergyStateResponse phía backend
/// (`GET /api/v1/me/energy` và trường `energy` trong SubmitActivityResponse).
///
/// Server là nguồn duy nhất: client KHÔNG suy balance từ `energyDeducted`
/// (server có thể lazy-recover trước submit) — luôn dùng snapshot này.
class EnergyStateDto {
  final int current;
  final int max;
  final int recoveryAmount;
  final int recoveryIntervalSeconds;

  /// Mốc hồi kế tiếp theo đồng hồ server — null khi đã đầy.
  final DateTime? nextRecoveryAt;

  /// Đồng hồ server tại thời điểm trả response — dùng để bù skew thiết bị
  /// khi đếm ngược (không tin tuyệt đối DateTime.now()).
  final DateTime? serverTime;

  /// Server đã kiểm gate: true = còn đủ Thể lực cho submission được chấm.
  /// Khi backend flag tắt thì luôn true (không phạt/không chặn).
  final bool canSubmitGraded;

  const EnergyStateDto({
    required this.current,
    required this.max,
    this.recoveryAmount = 0,
    this.recoveryIntervalSeconds = 0,
    this.nextRecoveryAt,
    this.serverTime,
    this.canSubmitGraded = true,
  });

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

  /// Offset đồng hồ: serverTime - deviceNow lúc parse. Dùng để quy
  /// [nextRecoveryAt] (giờ server) về thời lượng còn lại theo thiết bị.
  /// Null khi server không trả serverTime — caller fallback device clock.
  Duration? get serverOffset =>
      serverTime?.difference(DateTime.now().toUtc());

  /// Thời lượng còn lại tới mốc hồi — đã bù clock skew khi có serverTime.
  /// Trả null khi không có mốc (đầy). Không bao giờ âm.
  Duration? timeUntilNextRecovery() {
    final next = nextRecoveryAt;
    if (next == null) return null;
    final Duration offset = serverOffset ?? Duration.zero;
    final DateTime serverNow = DateTime.now().toUtc().add(offset);
    final Duration remain = next.difference(serverNow);
    return remain.isNegative ? Duration.zero : remain;
  }

  double get fraction => max <= 0 ? 0 : (current / max).clamp(0.0, 1.0);
  bool get isFull => current >= max;
  bool get isDepleted => current <= 0;

  /// Chu kỳ hồi dạng phút để hiển thị ("+5 Thể lực mỗi 15 phút").
  int get recoveryIntervalMinutes => recoveryIntervalSeconds ~/ 60;
}
