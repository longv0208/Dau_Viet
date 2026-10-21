import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/presentation/renderers/matching_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression cho bug precedence `!submitting && armed || paired` —
/// khi submitting=true, right tile đã paired KHÔNG được nhận tap
/// (unpair giữa request).
void main() {
  const activity = {
    'id': 'a',
    'type': 'MATCHING',
    'config': {
      'leftItems': [
        {'id': 'l1', 'label': 'Trái 1'},
        {'id': 'l2', 'label': 'Trái 2'},
      ],
      'rightItems': [
        {'id': 'r1', 'label': 'Phải 1'},
        {'id': 'r2', 'label': 'Phải 2'},
      ],
    },
    'feedback': {},
  };

  Widget buildApp({required bool submitting}) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MatchingRenderer(
          activity: ActivityRefDto.fromJson(activity),
          submitting: submitting,
          onSubmit: (_) async {},
        ),
      ),
    ),
  );

  testWidgets('paired right tile không thể unpair khi submitting', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(submitting: false));
    // Pair l1 → r1.
    await tester.tap(find.text('Trái 1'));
    await tester.pump();
    await tester.tap(find.text('Phải 1'));
    await tester.pump();
    expect(find.text('Đã ghép 1/2'), findsOneWidget);

    // Bật submitting → rebuild → tap vào right đã paired phải vô hiệu.
    await tester.pumpWidget(buildApp(submitting: true));
    await tester.pump();
    await tester.tap(find.text('Phải 1'), warnIfMissed: false);
    await tester.pump();
    // Vẫn giữ nguyên pair — không bị unpair do bug precedence.
    expect(find.text('Đã ghép 1/2'), findsOneWidget);
  });

  testWidgets('paired right tile vẫn unpair được khi KHÔNG submitting', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(submitting: false));
    await tester.tap(find.text('Trái 1'));
    await tester.pump();
    await tester.tap(find.text('Phải 1'));
    await tester.pump();
    expect(find.text('Đã ghép 1/2'), findsOneWidget);

    // Tap right đã paired khi không armed → unpair.
    await tester.tap(find.text('Phải 1'));
    await tester.pump();
    expect(find.text('Đã ghép 0/2'), findsOneWidget);
  });
}
