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
      final json = submitJson()..remove('energy')..remove('energyDeducted');
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
      // offset = -10m → serverNow = now-10m → remain ≈ 5m.
      expect(remain.inMinutes, 5);
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
}
