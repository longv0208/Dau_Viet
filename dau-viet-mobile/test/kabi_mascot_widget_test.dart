import 'package:dau_viet_mobile/core/widgets/kabi_mascot_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KabiMascotWidget Tests', () {
    testWidgets('renders fallback mascot in test environment safely', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KabiMascotWidget(
              mood: KabiMood.guiding,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      expect(find.byType(KabiMascotWidget), findsOneWidget);
    });

    testWidgets('tap triggers callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KabiMascotWidget(
              mood: KabiMood.cheering,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(KabiMascotWidget));
      expect(tapped, isTrue);
    });

    testWidgets('supports different mood states without throwing', (
      tester,
    ) async {
      for (final mood in KabiMood.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KabiMascotWidget(mood: mood),
            ),
          ),
        );
        expect(find.byType(KabiMascotWidget), findsOneWidget);
      }
    });
  });
}
