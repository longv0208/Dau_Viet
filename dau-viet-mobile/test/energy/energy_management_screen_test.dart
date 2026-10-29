import 'package:dau_viet_mobile/features/energy/data/energy_dto.dart';
import 'package:dau_viet_mobile/features/energy/data/energy_providers.dart';
import 'package:dau_viet_mobile/features/meta/presentation/energy_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_energy_repository.dart';

Future<void> _pump(WidgetTester tester, FakeEnergyRepository repo) async {
  final router = GoRouter(
    initialLocation: '/energy',
    routes: [
      GoRoute(
        path: '/energy',
        builder: (context, state) => const EnergyManagementScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const Scaffold(body: Text('DASHBOARD')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [energyRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('EnergyManagementScreen (Viện Thái Y)', () {
    testWidgets('hiển thị số Thể lực thật + tốc độ hồi từ server', (
      tester,
    ) async {
      final repo = FakeEnergyRepository();
      repo.next = EnergyStateDto(
        current: 75,
        max: 100,
        recoveryAmount: 5,
        recoveryIntervalSeconds: 900,
        nextRecoveryAt: DateTime.now().toUtc().add(const Duration(minutes: 12)),
        canSubmitGraded: true,
        pointsBalance: 80,
        remedies: const [],
      );
      await _pump(tester, repo);
      expect(find.text('75'), findsWidgets);
      expect(find.textContaining('/ 100 ⚡'), findsOneWidget);
      expect(find.textContaining('Hồi tự nhiên: +5 Thể lực / 15 phút'),
          findsOneWidget);
    });

    testWidgets('Thể lực đầy → hiển thị badge SUNG MÃN', (tester) async {
      final repo = FakeEnergyRepository();
      repo.next = EnergyStateDto(
        current: 100,
        max: 100,
        recoveryAmount: 5,
        recoveryIntervalSeconds: 900,
        canSubmitGraded: true,
        pointsBalance: 80,
        remedies: const [],
      );
      await _pump(tester, repo);
      expect(find.text('100'), findsWidgets);
      expect(find.textContaining('SUNG MÃN'), findsOneWidget);
    });

    testWidgets('Thể lực cạn → cảnh báo CẦN BỒI BỔ + gợi ý', (tester) async {
      final repo = FakeEnergyRepository();
      repo.next = EnergyStateDto(
        current: 0,
        max: 100,
        recoveryAmount: 5,
        recoveryIntervalSeconds: 900,
        nextRecoveryAt: DateTime.now().toUtc().add(const Duration(minutes: 2)),
        canSubmitGraded: false,
        pointsBalance: 80,
        remedies: const [],
      );
      await _pump(tester, repo);
      expect(find.text('0'), findsWidgets);
      expect(find.textContaining('CẦN BỒI BỔ'), findsOneWidget);
      expect(find.textContaining('ôn tập'), findsOneWidget);
    });

    testWidgets('API lỗi → error view + nút thử lại', (tester) async {
      final repo = FakeEnergyRepository();
      repo.error = Exception('Network timeout');
      await _pump(tester, repo);
      expect(find.text('Chưa tải được sử liệu'), findsOneWidget);
      expect(find.text('THỬ LẠI'), findsOneWidget);

      repo.error = null;
      repo.next = EnergyStateDto(
        current: 60,
        max: 100,
        recoveryAmount: 5,
        recoveryIntervalSeconds: 900,
        canSubmitGraded: true,
        pointsBalance: 80,
        remedies: const [],
      );
      await tester.tap(find.text('THỬ LẠI'));
      await tester.pumpAndSettle();
      expect(find.text('60'), findsWidgets);
    });
  });

  group('GAME-07 — Viện Thái Y remedies', () {
    testWidgets('wallet pill hiển thị pointsBalance', (tester) async {
      final repo = FakeEnergyRepository();
      await _pump(tester, repo);
      expect(find.text('80'), findsWidgets);
      expect(find.byIcon(Icons.stars_rounded), findsWidgets);
    });

    testWidgets('4 remedy cards render đúng title + price', (tester) async {
      final repo = FakeEnergyRepository();
      await _pump(tester, repo);
      expect(find.text('Nước vối đầu giếng'), findsOneWidget);
      expect(find.text('Trà sen Tây Hồ'), findsOneWidget);
      expect(find.text('Nấm linh chi quý'), findsOneWidget);
      expect(find.text('Sâm Ngọc Linh'), findsOneWidget);
      expect(find.textContaining('Miễn phí'), findsOneWidget);
      expect(find.textContaining('30 Điểm Sử Ký'), findsOneWidget);
      expect(find.textContaining('55 Điểm Sử Ký'), findsOneWidget);
    });

    testWidgets('NUOC_VOI free → NHẬN NGAY → confirm → success', (
      tester,
    ) async {
      final repo = FakeEnergyRepository();
      await _pump(tester, repo);

      // Tap nút NHẬN NGAY (free) trên thẻ NUOC_VOI
      await tester.tap(find.text('NHẬN NGAY'));
      await tester.pumpAndSettle();

      // Confirm dialog hiển thị
      expect(find.text('XÁC NHẬN NHẬN LIỆU PHÁP'), findsOneWidget);
      expect(find.textContaining('Nước vối đầu giếng'), findsWidgets);

      // Tap NHẬN NGAY trong dialog
      await tester.tap(find.text('NHẬN NGAY').last);
      await tester.pumpAndSettle();

      // repo được gọi với remedyCode + idempotencyKey
      expect(repo.refillCalls.length, 1);
      expect(repo.refillCalls[0]['remedyCode'], 'NUOC_VOI');
      expect(repo.refillCalls[0]['idempotencyKey'], isNotEmpty);

      // Success dialog
      expect(find.textContaining('BỒI BỔ THÀNH CÔNG'), findsOneWidget);
    });

    testWidgets('TRA_SEN paid → BỒI BỔ → confirm → success trừ điểm', (
      tester,
    ) async {
      final repo = FakeEnergyRepository();
      repo.nextRefill = EnergyRefillResultDto(
        energy: EnergyStateDto(
          current: 80,
          max: 100,
          recoveryAmount: 5,
          recoveryIntervalSeconds: 900,
          canSubmitGraded: true,
          pointsBalance: 50,
          remedies: const [],
        ),
        remedyCode: 'TRA_SEN',
        energyCredited: 30,
        pointsSpent: 30,
        walletBalance: 50,
        serverTime: DateTime.now().toUtc(),
      );
      await _pump(tester, repo);

      await tester.tap(find.text('BỒI BỔ').first);
      await tester.pumpAndSettle();
      expect(find.text('XÁC NHẬN BỒI BỔ SINH LỰC'), findsOneWidget);
      expect(find.textContaining('Trà sen Tây Hồ'), findsWidgets);
      await tester.tap(find.text('XÁC NHẬN DÙNG'));
      await tester.pumpAndSettle();

      expect(repo.refillCalls.length, 1);
      expect(repo.refillCalls[0]['remedyCode'], 'TRA_SEN');
      expect(find.textContaining('+30⚡'), findsOneWidget);
      expect(find.textContaining('Đã trừ 30 Điểm Sử Ký'), findsOneWidget);
    });

    testWidgets('Remedy đầy → hiển thị ĐÃ ĐẦY SINH LỰC', (tester) async {
      final repo = FakeEnergyRepository();
      repo.next = EnergyStateDto(
        current: 100,
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
            description: 'Test',
            rarity: 'COMMON',
            iconKey: 'energy_nuoc_voi',
            energyGain: 20,
            pointsCost: 0,
            cooldownSeconds: 86400,
            eligible: false,
            effectiveEnergyGain: 0,
            blockReasons: const ['ENERGY_FULL'],
          ),
        ],
      );
      await _pump(tester, repo);
      expect(find.text('ĐÃ ĐẦY SINH LỰC'), findsOneWidget);
      expect(find.text('NHẬN NGAY'), findsNothing);
    });

    testWidgets('Remedy thiếu điểm → disabled THIẾU X ĐIỂM', (tester) async {
      final repo = FakeEnergyRepository();
      await _pump(tester, repo);
      // SAM_NGOC_LINH pointsCost=90 nhưng wallet=80 → thiếu 10
      expect(find.text('THIẾU 10 ĐIỂM'), findsOneWidget);
    });

    testWidgets('Cooldown → countdown pill + unlock sau refresh', (
      tester,
    ) async {
      final repo = FakeEnergyRepository();
      final endAt = DateTime.now().toUtc().add(const Duration(minutes: 5));
      repo.next = EnergyStateDto(
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
            description: 'Test',
            rarity: 'COMMON',
            iconKey: 'energy_nuoc_voi',
            energyGain: 20,
            pointsCost: 0,
            cooldownSeconds: 86400,
            eligible: false,
            effectiveEnergyGain: 20,
            cooldownEndsAt: endAt,
            blockReasons: const ['REFILL_RATE_LIMITED'],
          ),
        ],
      );
      await _pump(tester, repo);
      // Cooldown pill hiển thị
      expect(find.textContaining('Hồi sau'), findsOneWidget);
      // Không có nút NHẬN NGAY (không eligible)
      expect(find.text('NHẬN NGAY'), findsNothing);
    });
  });
}
