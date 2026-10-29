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

/// Cho phép test ép mốc "bây giờ theo thiết bị" — dùng cho
/// `_deviceNowAtParse` và fallback `_serverNowAtParse` khi server không
/// trả serverTime. Chỉ dùng trong test — production luôn null.
DateTime Function()? _testNowUtcOverride;

/// Test-only: cài đồng hồ thiết bị giả. Trả hàm gỡ.
void Function() debugOverrideEnergyNow(DateTime Function() nowUtc) {
  _testNowUtcOverride = nowUtc;
  return () => _testNowUtcOverride = null;
}

/// "Bây giờ theo thiết bị" (UTC) — một điểm đọc duy nhất để test có thể
/// chốt mốc tuyệt đối, tránh so giây trên thời gian thực.
DateTime _deviceNowUtc() => _testNowUtcOverride != null
    ? _testNowUtcOverride!()
    : DateTime.now().toUtc();

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

  /// Số Điểm Sử Ký hiện có (GAME-07, Issue #28) — server quyết, ví
  /// _buildWalletPill đọc trực tiếp. Default 0 nếu backend cũ chưa gửi.
  final int pointsBalance;

  /// Catalog Viện Thái Y — remedies active với eligible/blockReasons
  /// do server quyết. Empty nếu backend cũ chưa gửi (GAME-02 only).
  final List<EnergyRemedyDto> remedies;

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
    this.pointsBalance = 0,
    this.remedies = const [],
  }) : _deviceNowAtParse = _deviceNowUtc(),
       _serverNowAtParse = serverTime ?? _deviceNowUtc(),
       _elapsedAtParse = (_testElapsedMicrosOverride ?? _stopwatchNowMicros)();

  factory EnergyStateDto.fromJson(Map<String, dynamic> json) {
    final remediesJson = json['remedies'];
    return EnergyStateDto(
      current: (json['current'] as num?)?.toInt() ?? 0,
      max: (json['max'] as num?)?.toInt() ?? 0,
      recoveryAmount: (json['recoveryAmount'] as num?)?.toInt() ?? 0,
      recoveryIntervalSeconds:
          (json['recoveryIntervalSeconds'] as num?)?.toInt() ?? 0,
      nextRecoveryAt: _parseInstant(json['nextRecoveryAt']),
      serverTime: _parseInstant(json['serverTime']),
      canSubmitGraded: json['canSubmitGraded'] as bool? ?? true,
      pointsBalance: (json['pointsBalance'] as num?)?.toInt() ?? 0,
      remedies: remediesJson is List
          ? remediesJson
              .whereType<Map<String, dynamic>>()
              .map(EnergyRemedyDto.fromJson)
              .toList()
          : const [],
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

/// DTO một vật phẩm Viện Thái Y (GAME-07, Issue #28) — khớp
/// EnergyRemedyDto phía backend. Server quyết `eligible`/`blockReasons`
/// (client chỉ render); `effectiveEnergyGain` là số Thể lực THỰC sẽ cộng
/// sau clamp trần max.
class EnergyRemedyDto {
  final String id;
  final String code;
  final String title;
  final String description;
  final String rarity;
  final String iconKey;
  final String? assetId;
  final int energyGain;
  final int pointsCost;
  final int cooldownSeconds;
  final bool eligible;
  final int effectiveEnergyGain;
  final DateTime? cooldownEndsAt;
  final List<String> blockReasons;

  const EnergyRemedyDto({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.rarity,
    required this.iconKey,
    this.assetId,
    required this.energyGain,
    required this.pointsCost,
    required this.cooldownSeconds,
    required this.eligible,
    required this.effectiveEnergyGain,
    this.cooldownEndsAt,
    required this.blockReasons,
  });

  factory EnergyRemedyDto.fromJson(Map<String, dynamic> json) {
    return EnergyRemedyDto(
      id: (json['id'] ?? '') as String,
      code: (json['code'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      rarity: (json['rarity'] ?? 'COMMON') as String,
      iconKey: (json['iconKey'] ?? 'energy_nuoc_voi') as String,
      assetId: json['assetId'] as String?,
      energyGain: (json['energyGain'] as num?)?.toInt() ?? 0,
      pointsCost: (json['pointsCost'] as num?)?.toInt() ?? 0,
      cooldownSeconds: (json['cooldownSeconds'] as num?)?.toInt() ?? 0,
      eligible: json['eligible'] as bool? ?? false,
      effectiveEnergyGain:
          (json['effectiveEnergyGain'] as num?)?.toInt() ?? 0,
      cooldownEndsAt: EnergyStateDto._parseInstant(json['cooldownEndsAt']),
      blockReasons: (json['blockReasons'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
    );
  }

  bool get isFree => pointsCost <= 0;
  bool get isRateLimited => blockReasons.contains('REFILL_RATE_LIMITED');
  bool get isEnergyFull => blockReasons.contains('ENERGY_FULL');
  bool get isInsufficientFunds =>
      blockReasons.contains('INSUFFICIENT_FUNDS');

  /// Asset path cho minh họa — khớp cấu trúc `assets/items/` của app.
  String get assetImagePath => 'assets/items/$iconKey.png';

  /// Thời gian còn lại tới khi remedy hết cooldown — dùng serverNow từ
  /// parent EnergyStateDto để bù clock skew.
  Duration? timeUntilAvailable(DateTime currentServerNow) {
    final ends = cooldownEndsAt;
    if (ends == null) return null;
    final Duration remain = ends.difference(currentServerNow);
    return remain.isNegative ? Duration.zero : remain;
  }
}

/// Response POST /api/v1/me/energy/refills — snapshot đầy đủ sau refill
/// để UI apply ngay (không cần GET lại).
class EnergyRefillResultDto {
  final EnergyStateDto energy;
  final String remedyCode;
  final int energyCredited;
  final int pointsSpent;
  final int walletBalance;
  final DateTime? refillAt;
  final DateTime? nextEligibleAt;
  final DateTime? serverTime;

  const EnergyRefillResultDto({
    required this.energy,
    required this.remedyCode,
    required this.energyCredited,
    required this.pointsSpent,
    required this.walletBalance,
    this.refillAt,
    this.nextEligibleAt,
    this.serverTime,
  });

  factory EnergyRefillResultDto.fromJson(Map<String, dynamic> json) {
    return EnergyRefillResultDto(
      energy: json['energy'] is Map<String, dynamic>
          ? EnergyStateDto.fromJson(json['energy'] as Map<String, dynamic>)
          : EnergyStateDto(current: 0, max: 0),
      remedyCode: (json['remedyCode'] ?? '') as String,
      energyCredited: (json['energyCredited'] as num?)?.toInt() ?? 0,
      pointsSpent: (json['pointsSpent'] as num?)?.toInt() ?? 0,
      walletBalance: (json['walletBalance'] as num?)?.toInt() ?? 0,
      refillAt: EnergyStateDto._parseInstant(json['refillAt']),
      nextEligibleAt: EnergyStateDto._parseInstant(json['nextEligibleAt']),
      serverTime: EnergyStateDto._parseInstant(json['serverTime']),
    );
  }
}
