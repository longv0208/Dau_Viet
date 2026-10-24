import 'package:dau_viet_mobile/features/energy/data/energy_dto.dart';
import 'package:dau_viet_mobile/features/energy/data/energy_providers.dart';
import 'package:dau_viet_mobile/features/meta/presentation/energy_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_energy_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeEnergyRepository repo,
) async {
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
      expect(
        find.textContaining('bản cập nhật tiếp theo'),
        findsOneWidget,
      );
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
      repo.next = const EnergyStateDto(current: 60, max: 100);
      await tester.tap(find.text('THỬ LẠI'));
      await tester.pumpAndSettle();
      expect(repo.calls, greaterThan(before));
      expect(find.text('60 / 100'), findsOneWidget);
    });
  });
}
