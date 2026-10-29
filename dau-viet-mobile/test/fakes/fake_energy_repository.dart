import 'package:dau_viet_mobile/features/energy/data/energy_dto.dart';
import 'package:dau_viet_mobile/features/energy/data/energy_repository.dart';

/// Scripted repo cho provider/widget test — KHÔNG phải MockEnergyRepository
/// của app (mock chỉ phục vụ USE_MOCK). Đếm số lần fetch + refill để test
/// không vô tình poll API.
class FakeEnergyRepository implements EnergyRepository {
  EnergyStateDto next = EnergyStateDto(
    current: 50,
    max: 100,
    recoveryAmount: 5,
    recoveryIntervalSeconds: 900,
    canSubmitGraded: true,
    pointsBalance: 80,
    remedies: [
      EnergyRemedyDto(
        id: '00000000-0000-4000-8000-000000000001',
        code: 'NUOC_VOI',
        title: 'Nước vối đầu giếng',
        description: 'Mát gan, nhẹ bụng. Gói cơ bản nhất của Viện Thái Y.',
        rarity: 'COMMON',
        iconKey: 'energy_nuoc_voi',
        energyGain: 20,
        pointsCost: 0,
        cooldownSeconds: 86400,
        eligible: true,
        effectiveEnergyGain: 20,
        blockReasons: const [],
      ),
      EnergyRemedyDto(
        id: '00000000-0000-4000-8000-000000000002',
        code: 'TRA_SEN',
        title: 'Trà sen Tây Hồ',
        description: 'Hương sen tỉnh tâm, giúp sĩ tử thu nạp đều đặn.',
        rarity: 'UNCOMMON',
        iconKey: 'energy_tra_sen',
        energyGain: 30,
        pointsCost: 30,
        cooldownSeconds: 14400,
        eligible: true,
        effectiveEnergyGain: 30,
        blockReasons: const [],
      ),
      EnergyRemedyDto(
        id: '00000000-0000-4000-8000-000000000003',
        code: 'NAM_LINH_CHI',
        title: 'Nấm linh chi quý',
        description: 'Dược liệu cao cấp phục hồi nhanh sinh lực.',
        rarity: 'RARE',
        iconKey: 'energy_nam_linh_chi',
        energyGain: 50,
        pointsCost: 55,
        cooldownSeconds: 43200,
        eligible: true,
        effectiveEnergyGain: 50,
        blockReasons: const [],
      ),
      EnergyRemedyDto(
        id: '00000000-0000-4000-8000-000000000004',
        code: 'SAM_NGOC_LINH',
        title: 'Sâm Ngọc Linh',
        description: 'Đỉnh cao dược liệu Viện Thái Y, phục hồi toàn bộ.',
        rarity: 'EPIC',
        iconKey: 'energy_sam_ngoc_linh',
        energyGain: 100,
        pointsCost: 90,
        cooldownSeconds: 86400,
        eligible: false,
        effectiveEnergyGain: 50,
        blockReasons: const ['INSUFFICIENT_FUNDS'],
      ),
    ],
  );

  Object? error;
  int calls = 0;

  /// Trả response khác nhau mỗi lần (queue) — để test refresh đổi data.
  final List<EnergyStateDto> queue = [];

  /// Scripted response cho POST refills — default: trả `next` với
  /// credited=0. Test nên gán `nextRefill` cho match thực tế.
  EnergyRefillResultDto? nextRefill;

  /// Ném thay vì trả khi test luồng lỗi.
  Object? refillError;

  /// Ghi lại lịch sử refill — assert key/code/key khớp Idempotency-Key.
  final List<Map<String, String>> refillCalls = [];

  @override
  Future<EnergyStateDto> getMyEnergy() async {
    calls++;
    if (error != null) throw error!;
    if (queue.isNotEmpty) return queue.removeAt(0);
    return next;
  }

  @override
  Future<EnergyRefillResultDto> refillEnergy({
    required String remedyCode,
    required String idempotencyKey,
  }) async {
    refillCalls.add(
        {'remedyCode': remedyCode, 'idempotencyKey': idempotencyKey});
    if (refillError != null) throw refillError!;
    return nextRefill ??
        EnergyRefillResultDto(
          energy: next,
          remedyCode: remedyCode,
          energyCredited: 0,
          pointsSpent: 0,
          walletBalance: next.pointsBalance,
          serverTime: DateTime.now().toUtc(),
        );
  }
}
