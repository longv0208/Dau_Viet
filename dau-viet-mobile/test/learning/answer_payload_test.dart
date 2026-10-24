import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/presentation/renderers/activity_renderer.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_dtos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper: render một activity độc lập với content rỗng, bắt payload submit.
Future<Map<String, dynamic>> submitFrom(
  WidgetTester tester,
  Map<String, dynamic> activityJson, {
  Future<void> Function(WidgetTester)? interact,
  String buttonText = 'GỬI CÂU TRẢ LỜI',
}) async {
  Map<String, dynamic>? captured;
  final activity = ActivityRefDto.fromJson(activityJson);
  const content = LessonContentDto(
    lessonId: 'l',
    lessonVersionId: 'v',
    content: {'evidence': [], 'assets': []},
  );

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivityRenderer(
              activity: activity,
              content: content,
              submitting: false,
              onSubmit: (a) async => captured = a,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (interact != null) await interact(tester);
  await tester.tap(find.text(buttonText));
  await tester.pump();
  return captured ?? const {};
}

void main() {
  group('Answer payload shapes — khớp contract server', () {
    testWidgets('READ submit {}', (tester) async {
      final payload = await submitFrom(tester, {
        'id': 'a1',
        'type': 'READ',
        'config': {'title': 'T', 'body': 'B'},
      }, buttonText: 'ĐÃ ĐỌC XONG, TIẾP TỤC');
      expect(payload, isEmpty);
    });

    testWidgets('MULTIPLE_CHOICE single → {selectedOptionIds:[id]}', (
      tester,
    ) async {
      final payload = await submitFrom(
        tester,
        {
          'id': 'a2',
          'type': 'MULTIPLE_CHOICE',
          'config': {
            'question': 'Q?',
            'multiSelect': false,
            'options': [
              {'id': 'o1', 'label': 'A'},
              {'id': 'o2', 'label': 'B'},
            ],
          },
        },
        interact: (t) async {
          await t.tap(find.text('A'));
          await t.pump();
        },
      );
      expect(payload, {
        'selectedOptionIds': ['o1'],
      });
    });

    testWidgets('MULTIPLE_CHOICE multi → gom nhiều ids', (tester) async {
      final payload = await submitFrom(
        tester,
        {
          'id': 'a2b',
          'type': 'MULTIPLE_CHOICE',
          'config': {
            'question': 'Q?',
            'multiSelect': true,
            'options': [
              {'id': 'o1', 'label': 'A'},
              {'id': 'o2', 'label': 'B'},
              {'id': 'o3', 'label': 'C'},
            ],
          },
        },
        interact: (t) async {
          await t.tap(find.text('A'));
          await t.tap(find.text('C'));
          await t.pump();
        },
      );
      expect((payload['selectedOptionIds'] as List).toSet(), {'o1', 'o3'});
    });

    testWidgets('MATCHING → {pairs:[{leftId,rightId}]}', (tester) async {
      final payload = await submitFrom(
        tester,
        {
          'id': 'a3',
          'type': 'MATCHING',
          'config': {
            'leftItems': [
              {'id': 'L1', 'label': 'Trái 1'},
            ],
            'rightItems': [
              {'id': 'R1', 'label': 'Phải 1'},
            ],
          },
        },
        interact: (t) async {
          await t.tap(find.text('Trái 1'));
          await t.pump();
          await t.tap(find.text('Phải 1'));
          await t.pump();
        },
      );
      expect(payload, {
        'pairs': [
          {'leftId': 'L1', 'rightId': 'R1'},
        ],
      });
    });

    testWidgets('DRAG_ORDER → {orderedIds} giữ thứ tự server', (tester) async {
      final payload = await submitFrom(tester, {
        'id': 'a4',
        'type': 'DRAG_ORDER',
        'config': {
          'items': [
            {'id': 's2', 'label': 'Sau'},
            {'id': 's1', 'label': 'Trước'},
            {'id': 's3', 'label': 'Cuối'},
          ],
        },
      });
      // Không reorder → orderedIds = thứ tự server đã shuffle.
      expect(payload, {
        'orderedIds': ['s2', 's1', 's3'],
      });
    });

    testWidgets('CER → {claim, evidenceIds, reasoning}', (tester) async {
      final payload = await submitFrom(
        tester,
        {'id': 'a5', 'type': 'CER', 'config': {}},
        interact: (t) async {
          await t.enterText(
            find.byType(TextField).at(0),
            'Cọc ngầm là yếu tố quyết định chiến thắng',
          );
          await t.enterText(
            find.byType(TextField).at(1),
            'Vì thuyền địch mắc cọc khi triều rút mất khả năng cơ động',
          );
          await t.pump();
        },
      );
      expect(payload['claim'], isNotEmpty);
      expect(payload['reasoning'], isNotEmpty);
      expect(payload['evidenceIds'], isA<List>());
    });

    testWidgets('REFLECTION_PROMPT text → {text}', (tester) async {
      final payload = await submitFrom(
        tester,
        {
          'id': 'a6',
          'type': 'REFLECTION_PROMPT',
          'config': {'prompt': 'Bạn nghĩ gì?'},
        },
        interact: (t) async {
          await t.enterText(find.byType(TextField), 'Bài học rất hay');
          await t.pump();
        },
      );
      expect(payload, {'text': 'Bài học rất hay'});
    });

    testWidgets('VERIFICATION → {action:"verify"} (Learning Flow 2.0)', (
      tester,
    ) async {
      final payload = await submitFrom(tester, {
        'id': 'a7',
        'type': 'VERIFICATION',
        'config': {'prompt': 'Kiểm chứng lại các nguồn'},
      }, buttonText: 'KIỂM CHỨNG');
      expect(payload, {'action': 'verify'});
    });

    testWidgets('VERIFICATION hiển thị giả thuyết + bằng chứng từ priorOutputs', (
      tester,
    ) async {
      Map<String, dynamic>? captured;
      final activity = ActivityRefDto.fromJson({
        'id': 'vf1',
        'type': 'VERIFICATION',
        'config': {
          'evidenceSource': 'es',
          'priorOutputs': {
            'hy1': {'hypothesisId': 'h-tide'},
            'es': {
              'selectedEvidenceIds': ['e1', 'e2'],
            },
          },
        },
      });
      const content = LessonContentDto(
        lessonId: 'l',
        lessonVersionId: 'v',
        content: {
          'evidence': [
            {'id': 'e1', 'title': 'Sử thần ghi triều'},
            {'id': 'e2', 'title': 'Khảo cổ cọc'},
          ],
          'assets': [],
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ActivityRenderer(
                  activity: activity,
                  content: content,
                  submitting: false,
                  onSubmit: (a) async => captured = a,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('GIẢ THUYẾT ĐÃ CHỌN'), findsOneWidget);
      expect(find.text('h-tide'), findsOneWidget);
      expect(find.text('BẰNG CHỨNG ĐÃ THU THẬP'), findsOneWidget);
      expect(find.text('Sử thần ghi triều'), findsOneWidget);
      expect(find.text('Khảo cổ cọc'), findsOneWidget);
      await tester.tap(find.text('KIỂM CHỨNG'));
      await tester.pump();
      expect(captured, {'action': 'verify'});
    });

    testWidgets('VIEW_IMAGE không asset → submit {}', (tester) async {
      final payload = await submitFrom(tester, {
        'id': 'a8',
        'type': 'VIEW_IMAGE',
        'config': {},
      }, buttonText: 'ĐÃ QUAN SÁT, TIẾP TỤC');
      expect(payload, isEmpty);
    });

    testWidgets('type lạ → UnsupportedRenderer không nút submit', (
      tester,
    ) async {
      Map<String, dynamic>? captured;
      final activity = ActivityRefDto.fromJson({
        'id': 'a9',
        'type': 'HOLOGRAM_3D',
        'config': {},
      });
      const content = LessonContentDto(
        lessonId: 'l',
        lessonVersionId: 'v',
        content: {},
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ActivityRenderer(
                activity: activity,
                content: content,
                submitting: false,
                onSubmit: (a) async => captured = a,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('HOLOGRAM_3D'), findsOneWidget);
      expect(find.text('GỬI CÂU TRẢ LỜI'), findsNothing);
      expect(captured, isNull);
    });
  });
}
