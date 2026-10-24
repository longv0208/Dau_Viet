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
      final repo = FakeEnergyRepository()
        ..next = EnergyStateDto(
          current: 75,
          max: 100,
          recoveryAmount: 5,
          recoveryIntervalSeconds: 900,
          nextRecoveryAt: DateTime.now().toUtc().add(
            const Duration(minutes: 8, seconds: 42),
          ),
          serverTime: DateTime.now().toUtc(),
          canSubmitGraded: true,
        );
      await _pump(tester, repo);
      expect(find.text('75 / 100'), findsOneWidget);
      expect(find.textContaining('+5 Thể lực mỗi 15 phút'), findsOneWidget);
      expect(find.textContaining('Hồi tiếp sau'), findsOneWidget);
    });

    testWidgets('Thể lực đầy → "đã đầy", không countdown', (tester) async {
      final repo = FakeEnergyRepository()
        ..next = EnergyStateDto(
          current: 100,
          max: 100,
          recoveryAmount: 5,
          recoveryIntervalSeconds: 900,
          nextRecoveryAt: null,
          serverTime: DateTime.now().toUtc(),
        );
      await _pump(tester, repo);
      expect(find.text('100 / 100'), findsOneWidget);
      expect(find.textContaining('đã đầy'), findsOneWidget);
      expect(find.textContaining('Hồi tiếp sau'), findsNothing);
    });

    testWidgets('Thể lực cạn → thông báo + gợi ý ôn tập', (tester) async {
      final repo = FakeEnergyRepository()
        ..next = EnergyStateDto(
          current: 0,
          max: 100,
          recoveryAmount: 5,
          recoveryIntervalSeconds: 900,
          nextRecoveryAt: DateTime.now().toUtc().add(
            const Duration(minutes: 12),
          ),
          serverTime: DateTime.now().toUtc(),
          canSubmitGraded: false,
        );
      await _pump(tester, repo);
      expect(find.text('0 / 100'), findsOneWidget);
      expect(find.textContaining('Thể lực đã cạn'), findsOneWidget);
      expect(find.textContaining('ôn tập'), findsOneWidget);
    });

    testWidgets('KHÔNG còn nút cộng năng lượng giả — các liệu pháp '
        'hiển thị "Sắp mở" và không tương tác', (tester) async {
      final repo = FakeEnergyRepository()
        ..next = EnergyStateDto(
          current: 50,
          max: 100,
          recoveryAmount: 5,
          recoveryIntervalSeconds: 900,
          serverTime: DateTime.now().toUtc(),
        );
      await _pump(tester, repo);
      // Không còn CTA hồi miễn phí +20 — đã bị xoá.
      expect(find.textContaining('HỒI PHỤC NGAY'), findsNothing);
      expect(find.textContaining('Miễn phí'), findsNothing);
      // Liệu pháp "Sắp mở" — không tap được.
      expect(find.text('Sắp mở'), findsNWidgets(4));
      // Thông báo cập nhật sau.
      expect(find.textContaining('bản cập nhật tiếp theo'), findsOneWidget);
      // Giá trị năng lượng không đổi sau tap vào liệu pháp (không tương tác).
      await tester.tap(find.text('Nước Vối Tĩnh Tâm'));
      await tester.pumpAndSettle();
      expect(find.text('50 / 100'), findsOneWidget);
    });

    testWidgets('API lỗi → error view + nút thử lại, KHÔNG 80/100 giả', (
      tester,
    ) async {
      final repo = FakeEnergyRepository()..error = Exception('down');
      await _pump(tester, repo);
      expect(find.text('80 / 100'), findsNothing);
      expect(find.text('100 / 100'), findsNothing);
      // Retry gọi lại repo.
      final before = repo.calls;
      repo.error = null;
      repo.next = EnergyStateDto(current: 60, max: 100);
      await tester.tap(find.text('THỬ LẠI'));
      await tester.pumpAndSettle();
      expect(repo.calls, greaterThan(before));
      expect(find.text('60 / 100'), findsOneWidget);
    });
  });

  group('FIX-2 — countdown chạy + refresh đúng 1 lần khi chạm 0', () {
    testWidgets('countdown giảm thực sự theo thời gian (không đứng yên)', (
      tester,
    ) async {
      int fakeMicros = 0;
      final restore = debugOverrideEnergyClock(() => fakeMicros);
      addTearDown(restore);

      // Mốc hồi cách parse 90s (ở fake t=0).
      final t0 = DateTime.now().toUtc();
      final repo = FakeEnergyRepository()
        ..next = EnergyStateDto(
          current: 50,
          max: 100,
          recoveryAmount: 5,
          recoveryIntervalSeconds: 900,
          serverTime: t0,
          nextRecoveryAt: t0.add(const Duration(seconds: 90)),
        );
      await _pump(tester, repo);
      expect(find.textContaining('Hồi tiếp sau 01:30'), findsOneWidget);

      // Trôi 30s theo ĐỒNG HỒ ĐƠN ĐIỆU + pump frame → countdown giảm.
      fakeMicros = const Duration(seconds: 30).inMicroseconds;
      await tester.pump(const Duration(seconds: 30));
      expect(find.textContaining('Hồi tiếp sau 01:00'), findsOneWidget);

      fakeMicros = const Duration(seconds: 89).inMicroseconds;
      await tester.pump(const Duration(seconds: 59));
      expect(find.textContaining('Hồi tiếp sau 00:01'), findsOneWidget);
    });

    testWidgets('chạm 0 → đúng MỘT refresh; state mới có mốc mới → '
        'countdown chạy lại', (tester) async {
      int fakeMicros = 0;
      final restore = debugOverrideEnergyClock(() => fakeMicros);
      addTearDown(restore);

      final t0 = DateTime.now().toUtc();
      // initState của màn luôn refresh 1 lần sau khi mount → queue cần 3
      // mục: build + init-refresh (cùng state 50, còn 3s) + refresh-lúc-0
      // (server đã +5 → 55, mốc mới còn 60s).
      EnergyStateDto fifty() => EnergyStateDto(
        current: 50,
        max: 100,
        recoveryAmount: 5,
        recoveryIntervalSeconds: 900,
        serverTime: t0,
        nextRecoveryAt: t0.add(const Duration(seconds: 3)),
      );
      final repo = FakeEnergyRepository()
        ..queue.addAll([
          fifty(),
          fifty(),
          EnergyStateDto(
            current: 55,
            max: 100,
            recoveryAmount: 5,
            recoveryIntervalSeconds: 900,
            serverTime: t0.add(const Duration(seconds: 3)),
            nextRecoveryAt: t0.add(const Duration(seconds: 63)),
          ),
        ]);
      await _pump(tester, repo);
      expect(find.text('50 / 100'), findsOneWidget);
      final callsAfterFirstLoad = repo.calls;

      // Trôi qua mốc → ticker tick → _maybeRefreshAtZero → đúng 1 refresh.
      fakeMicros = const Duration(seconds: 4).inMicroseconds;
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(repo.calls, callsAfterFirstLoad + 1);
      expect(find.text('55 / 100'), findsOneWidget);
      // Countdown chạy lại với mốc mới — đã trôi 4s+ (fake clock) nên
      // remain nằm trong khoảng 00:5x thay vì mốc cứng.
      expect(
        find.textContaining(RegExp(r'Hồi tiếp sau 00:5[0-9]')),
        findsOneWidget,
      );

      // Tick thêm vài giây — KHÔNG refresh lại (mốc mới chưa tới).
      fakeMicros += const Duration(seconds: 5).inMicroseconds;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.calls, callsAfterFirstLoad + 1);
    });

    testWidgets('Thể lực đầy → KHÔNG có refresh định kỳ nào cả', (
      tester,
    ) async {
      final restore = debugOverrideEnergyClock(() => 0);
      addTearDown(restore);

      final repo = FakeEnergyRepository()
        ..next = EnergyStateDto(
          current: 100,
          max: 100,
          recoveryAmount: 5,
          recoveryIntervalSeconds: 900,
          nextRecoveryAt: null,
          serverTime: DateTime.now().toUtc(),
        );
      await _pump(tester, repo);
      final calls = repo.calls;

      // Trôi nhiều phút + nhiều pump — không timer countdown → không gọi lại.
      await tester.pump(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(repo.calls, calls);
    });
  });
}
