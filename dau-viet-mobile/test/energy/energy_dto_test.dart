import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/features/energy/data/energy_dto.dart';
import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnergyStateDto.fromJson (GET /me/energy)', () {
    test('parse đầy đủ trường', () {
      final dto = EnergyStateDto.fromJson(const {
        'current': 75,
        'max': 100,
        'recoveryAmount': 5,
        'recoveryIntervalSeconds': 900,
        'nextRecoveryAt': '2026-10-25T10:15:00Z',
        'serverTime': '2026-10-25T10:05:00Z',
        'canSubmitGraded': true,
      });
      expect(dto.current, 75);
      expect(dto.max, 100);
      expect(dto.recoveryAmount, 5);
      expect(dto.recoveryIntervalSeconds, 900);
      expect(dto.nextRecoveryAt, isNotNull);
      expect(dto.serverTime, isNotNull);
      expect(dto.canSubmitGraded, isTrue);
      expect(dto.recoveryIntervalMinutes, 15);
    });

    test('nextRecoveryAt=null (đầy) parse được', () {
      final dto = EnergyStateDto.fromJson(const {
        'current': 100,
        'max': 100,
        'recoveryAmount': 5,
        'recoveryIntervalSeconds': 900,
        'nextRecoveryAt': null,
        'serverTime': '2026-10-25T10:05:00Z',
        'canSubmitGraded': true,
      });
      expect(dto.isFull, isTrue);
      expect(dto.nextRecoveryAt, isNull);
      expect(dto.timeUntilNextRecovery(), isNull);
    });

    test('current=0 → depleted, canSubmitGraded=false', () {
      final dto = EnergyStateDto.fromJson(const {
        'current': 0,
        'max': 100,
        'recoveryAmount': 5,
        'recoveryIntervalSeconds': 900,
        'nextRecoveryAt': '2026-10-25T10:15:00Z',
        'serverTime': '2026-10-25T10:05:00Z',
        'canSubmitGraded': false,
      });
      expect(dto.isDepleted, isTrue);
      expect(dto.canSubmitGraded, isFalse);
    });

    test('thiếu trường optional → default an toàn (backward-compat)', () {
      final dto = EnergyStateDto.fromJson(const {'current': 40, 'max': 100});
      expect(dto.recoveryAmount, 0);
      expect(dto.canSubmitGraded, isTrue); // flag-off server coi là true
    });
  });

  group('SubmitResultDto — GAME-03 additive fields', () {
    Map<String, dynamic> submitJson({bool withEnergy = true}) => {
      'status': 'ACCEPTED',
      'evaluation': {'outcome': 'INCORRECT', 'completed': false},
      'activityCompleted': false,
      'progress': {'completedRequired': 0, 'totalRequired': 2},
      'completion': {'complete': false},
      'energyDeducted': 10,
      if (withEnergy)
        'energy': {
          'current': 40,
          'max': 100,
          'recoveryAmount': 5,
          'recoveryIntervalSeconds': 900,
          'nextRecoveryAt': '2026-10-25T10:15:00Z',
          'serverTime': '2026-10-25T10:05:00Z',
          'canSubmitGraded': true,
        },
    };

    test('parse energy + energyDeducted', () {
      final dto = SubmitResultDto.fromJson(submitJson());
      expect(dto.energyDeducted, 10);
      expect(dto.energy, isNotNull);
      expect(dto.energy!.current, 40);
      expect(dto.energy!.max, 100);
    });

    test('thiếu energy (server cũ/mock) → null an toàn', () {
      final dto = SubmitResultDto.fromJson(submitJson(withEnergy: false));
      expect(dto.energy, isNull);
      expect(dto.energyDeducted, 10); // vẫn đọc được deducted
    });

    test('thiếu cả hai trường (legacy) → deducted=0, energy=null', () {
      final json = submitJson()
        ..remove('energy')
        ..remove('energyDeducted');
      final dto = SubmitResultDto.fromJson(json);
      expect(dto.energyDeducted, 0);
      expect(dto.energy, isNull);
    });
  });

  group('ENERGY_DEPLETED error details', () {
    test('ApiError giữ details Map cho handler đọc', () {
      const err = ApiError(
        code: 'ENERGY_DEPLETED',
        message: 'Hết thể lực',
        details: {
          'currentEnergy': 0,
          'nextRecoveryAt': '2026-10-25T10:15:00Z',
          'serverTime': '2026-10-25T10:05:00Z',
        },
      );
      final details = err.details as Map;
      expect(details['currentEnergy'], 0);
      expect(DateTime.tryParse(details['nextRecoveryAt'] as String), isNotNull);
    });
  });

  group('EnergyStateDto countdown helpers', () {
    test('timeUntilNextRecovery bù serverTime', () {
      // serverTime cách đây 10 phút; nextRecovery còn 5 phút theo server.
      final now = DateTime.now().toUtc();
      final dto = EnergyStateDto(
        current: 50,
        max: 100,
        serverTime: now.subtract(const Duration(minutes: 10)),
        nextRecoveryAt: now.subtract(const Duration(minutes: 5)),
      );
      final remain = dto.timeUntilNextRecovery()!;
      // offset = -10m → serverNow = now-10m → remain ≈ 5m (± vài giây
      // vì có thời gian thực trôi giữa parse và đọc).
      expect(
        remain.inMilliseconds,
        greaterThan(const Duration(minutes: 4, seconds: 55).inMilliseconds),
      );
      expect(
        remain.inMilliseconds,
        lessThanOrEqualTo(const Duration(minutes: 5).inMilliseconds),
      );
    });

    test('remain âm → clamp về 0 (mốc đã qua)', () {
      final now = DateTime.now().toUtc();
      final dto = EnergyStateDto(
        current: 50,
        max: 100,
        serverTime: now,
        nextRecoveryAt: now.subtract(const Duration(seconds: 5)),
      );
      expect(dto.timeUntilNextRecovery(), Duration.zero);
    });
  });

  group('FIX-2 — countdown chạy thật theo đồng hồ đơn điệu', () {
    int fakeMicros = 0;
    DateTime? fakeNowUtc;
    void Function()? restore;
    void Function()? restoreNow;

    setUp(() {
      fakeMicros = 0;
      fakeNowUtc = null;
      restore = debugOverrideEnergyClock(() => fakeMicros);
      // Ép mốc "device-now" cố định để fallback khi thiếu serverTime có
      // thể so giây chính xác — không phụ thuộc thời gian thực giữa lúc
      // tạo mốc next và lúc constructor chạy.
      restoreNow = debugOverrideEnergyNow(
        () => fakeNowUtc ?? DateTime.now().toUtc(),
      );
    });
    tearDown(() {
      restore?.call();
      restoreNow?.call();
    });

    EnergyStateDto dtoAt({
      required int current,
      required DateTime serverTime,
      DateTime? nextRecovery,
    }) => EnergyStateDto(
      current: current,
      max: 100,
      recoveryAmount: 5,
      recoveryIntervalSeconds: 900,
      serverTime: serverTime,
      nextRecoveryAt: nextRecovery,
    );

    test('đếm ngược giảm đúng: 08:42 → 07:42 → 00:00', () {
      final t0 = DateTime.utc(2026, 10, 25, 10, 0);
      final dto = dtoAt(
        current: 50,
        serverTime: t0,
        nextRecovery: t0.add(const Duration(minutes: 8, seconds: 42)),
      );
      expect(
        dto.timeUntilNextRecovery(),
        const Duration(minutes: 8, seconds: 42),
      );

      fakeMicros = const Duration(seconds: 60).inMicroseconds;
      expect(
        dto.timeUntilNextRecovery(),
        const Duration(minutes: 7, seconds: 42),
      );

      fakeMicros = const Duration(minutes: 8, seconds: 42).inMicroseconds;
      expect(dto.timeUntilNextRecovery(), Duration.zero);

      // Quá mốc — không âm, không hồi sớm.
      fakeMicros = const Duration(minutes: 9).inMicroseconds;
      expect(dto.timeUntilNextRecovery(), Duration.zero);
    });

    test('clock skew: server chậm device 2h — vẫn đếm đúng theo server', () {
      // serverTime lệch device nhiều giờ; mốc hồi là giờ server.
      final serverNow = DateTime.utc(2026, 10, 25, 8, 0); // server
      final dto = dtoAt(
        current: 50,
        serverTime: serverNow,
        nextRecovery: serverNow.add(const Duration(minutes: 5)),
      );
      expect(dto.timeUntilNextRecovery(), const Duration(minutes: 5));
      fakeMicros = const Duration(minutes: 2).inMicroseconds;
      expect(dto.timeUntilNextRecovery(), const Duration(minutes: 3));
    });

    test('đầy (nextRecoveryAt=null) → luôn null, không phụ thuộc clock', () {
      final dto = dtoAt(
        current: 100,
        serverTime: DateTime.utc(2026, 10, 25),
        nextRecovery: null,
      );
      expect(dto.timeUntilNextRecovery(), isNull);
      fakeMicros = const Duration(hours: 1).inMicroseconds;
      expect(dto.timeUntilNextRecovery(), isNull);
    });

    test('thiếu serverTime → fallback mốc device lúc parse, vẫn đếm', () {
      // Chốt device-now để next − serverNowAtParse = đúng 30s — so giây
      // trên mốc giả, không trên DateTime.now() thật (inSeconds floor
      // từng làm CI fail 30 → 29).
      fakeNowUtc = DateTime.utc(2026, 10, 25, 10, 0);
      final next = fakeNowUtc!.add(const Duration(seconds: 30));
      final dto = EnergyStateDto(
        current: 50,
        max: 100,
        nextRecoveryAt: next,
      ); // serverTime null → serverNowAtParse = fakeNowUtc
      expect(dto.timeUntilNextRecovery(), const Duration(seconds: 30));
      fakeMicros = const Duration(seconds: 10).inMicroseconds;
      expect(dto.timeUntilNextRecovery(), const Duration(seconds: 20));
    });
  });
}
