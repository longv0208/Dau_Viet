import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dau_viet_mobile/core/widgets/ambient_atmosphere_overlay.dart';
import 'package:dau_viet_mobile/core/widgets/interactive_historical_mascot_widget.dart';
import 'package:dau_viet_mobile/features/energy/data/energy_providers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/context_reader_screen.dart';
import 'package:dau_viet_mobile/features/learning/presentation/multiple_choice_quiz_screen.dart';
import 'package:dau_viet_mobile/features/rewards/data/reward_dtos.dart';
import 'package:dau_viet_mobile/features/rewards/data/reward_providers.dart';

import 'fakes/fake_energy_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AmbientAtmosphereOverlay Widget Tests', () {
    testWidgets('Renders child content within goldEmbers mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AmbientAtmosphereOverlay(
              mode: AtmosphereMode.goldEmbers,
              child: Text('Nội dung trang sử'),
            ),
          ),
        ),
      );

      expect(find.text('Nội dung trang sử'), findsOneWidget);
    });

    testWidgets('Renders child content within riverMist mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AmbientAtmosphereOverlay(
              mode: AtmosphereMode.riverMist,
              backgroundImage: 'assets/images/bg_story_tran_dia.jpg',
              child: Text('Trận địa cọc'),
            ),
          ),
        ),
      );

      expect(find.text('Trận địa cọc'), findsOneWidget);
    });
  });

  group('InteractiveHistoricalMascotWidget Tests', () {
    testWidgets('Renders guiding state with speech bubble', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InteractiveHistoricalMascotWidget(
              state: MascotState.guiding,
              message: 'Hãy đọc kỹ lời bình sử thi!',
            ),
          ),
        ),
      );

      expect(find.text('BẠN ĐỒNG HÀNH'), findsOneWidget);
      expect(find.text('Hãy đọc kỹ lời bình sử thi!'), findsOneWidget);
    });

    testWidgets('Renders cheering state with celebration message', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InteractiveHistoricalMascotWidget(
              state: MascotState.cheering,
              message: 'Khải hoàn thắng lợi!',
            ),
          ),
        ),
      );

      expect(find.text('SĨ TỬ KHEN NGỢI'), findsOneWidget);
      expect(find.text('Khải hoàn thắng lợi!'), findsOneWidget);
    });

    testWidgets('Renders thinking state with hint message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InteractiveHistoricalMascotWidget(
              state: MascotState.thinking,
              message: 'Gợi ý: Cọc gỗ lim vót nhọn.',
            ),
          ),
        ),
      );

      expect(find.text('SĨ TỬ GỢI Ý'), findsOneWidget);
      expect(find.text('Gợi ý: Cọc gỗ lim vót nhọn.'), findsOneWidget);
    });

    testWidgets('Tap on mascot triggers callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveHistoricalMascotWidget(
              state: MascotState.guiding,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InteractiveHistoricalMascotWidget));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('Screen Visual Storytelling Integration Tests', () {
    testWidgets('ContextReaderScreen renders with mascot guide', (
      tester,
    ) async {
      // ProviderScope + fake energy repo: EnergyPill trong header giờ đọc
      // energyProvider (GAME-03) — override để không gọi HTTP thật.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            energyRepositoryProvider.overrideWithValue(
              FakeEnergyRepository(),
            ),
            // EnergyPill watch rewardSummaryProvider — trả giá trị tĩnh
            // để không gọi HTTP thật trong widget test.
            rewardSummaryProvider.overrideWith(
              (ref) async => RewardSummaryDto.empty,
            ),
          ],
          child: const MaterialApp(home: ContextReaderScreen()),
        ),
      );

      expect(find.byType(InteractiveHistoricalMascotWidget), findsOneWidget);
      expect(find.byType(AmbientAtmosphereOverlay), findsOneWidget);
    });

    testWidgets('MultipleChoiceQuizScreen renders with dynamic mascot', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: MultipleChoiceQuizScreen()),
      );

      expect(find.byType(InteractiveHistoricalMascotWidget), findsOneWidget);
      expect(find.byType(AmbientAtmosphereOverlay), findsOneWidget);
    });
  });
}
