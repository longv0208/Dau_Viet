import 'package:dau_viet_mobile/core/widgets/energy_pill.dart';
import 'package:dau_viet_mobile/features/energy/data/energy_dto.dart';
import 'package:dau_viet_mobile/features/energy/data/energy_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_energy_repository.dart';

void main() {
  group('EnergyPill', () {
    testWidgets('hiển thị số Thể lực thật từ provider', (tester) async {
      final repo = FakeEnergyRepository()
        ..next = EnergyStateDto(current: 75, max: 100);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [energyRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: Scaffold(body: Center(child: EnergyPill())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('75/100'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    });

    testWidgets('energy=0 → text 0/100 màu cảnh báo (vẫn là số thật)', (
      tester,
    ) async {
      final repo = FakeEnergyRepository()
        ..next = EnergyStateDto(current: 0, max: 100, canSubmitGraded: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [energyRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: Scaffold(body: Center(child: EnergyPill())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0/100'), findsOneWidget);
    });

    testWidgets('API lỗi → icon retry, KHÔNG hiện 100/100 giả', (tester) async {
      final repo = FakeEnergyRepository()..error = Exception('network down');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [energyRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: Scaffold(body: Center(child: EnergyPill())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('100/100'), findsNothing);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      // Retry → repo được gọi thêm.
      final before = repo.calls;
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();
      expect(repo.calls, greaterThan(before));
    });

    testWidgets('tap vào pill gọi onEnergyTap (điều hướng Viện Thái Y)', (
      tester,
    ) async {
      var tapped = false;
      final repo = FakeEnergyRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [energyRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: EnergyPill(onEnergyTap: () => tapped = true)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(EnergyPill));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });
}
