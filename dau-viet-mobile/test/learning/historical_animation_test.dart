import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/content/bach_dang_938_tide_v1.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/historical_animation_definition.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/historical_animation_player.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/historical_animation_registry.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/scenes/river_scene.dart';
import 'package:dau_viet_mobile/features/learning/presentation/renderers/read_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ActivityRefDto _readActivity(Map<String, dynamic> config) =>
    ActivityRefDto.fromJson({
      'id': 'act-anim',
      'type': 'READ',
      'config': config,
      'feedback': const <String, dynamic>{},
    });

Future<void> _pumpPlayer(
  WidgetTester tester, {
  HistoricalAnimationDefinition? definition,
  bool disableAnimations = false,
  Size surface = const Size(800, 1200),
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: surface,
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: HistoricalAnimationPlayer(
              definition: definition ?? bachDang938TideV1,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpRead(
  WidgetTester tester,
  Map<String, dynamic> config, {
  required Future<void> Function(Map<String, dynamic>) onSubmit,
  Size surface = const Size(800, 1600),
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: surface),
        child: Scaffold(
          body: SingleChildScrollView(
            child: ReadRenderer(
              activity: _readActivity(config),
              submitting: false,
              onSubmit: onSubmit,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Cuộn tới finder rồi tap — nội dung player dài hơn viewport test.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pump();
}

void main() {
  group('HistoricalAnimationRegistry', () {
    test('resolves the registered Bach Dang scene', () {
      final def = HistoricalAnimationRegistry.resolve('bach_dang_938_tide_v1');
      expect(def, isNotNull);
      expect(def!.key, 'bach_dang_938_tide_v1');
      expect(def.steps, hasLength(6));
      expect(def.createPainter(), isA<RiverScenePainter>());
    });

    test('unknown, null and empty keys resolve to null', () {
      expect(HistoricalAnimationRegistry.resolve('khong_ton_tai_v9'), isNull);
      expect(HistoricalAnimationRegistry.resolve(null), isNull);
      expect(HistoricalAnimationRegistry.resolve(''), isNull);
    });
  });

  group('HistoricalScenePainter state sync', () {
    test('setters notify repaint listeners (regression: frozen canvas)', () {
      // Player keeps ONE painter instance — without notifyListeners the
      // RenderCustomPaint would skip repaints and the scene would freeze.
      final painter = RiverScenePainter();
      var notified = 0;
      painter.addListener(() => notified++);
      painter.waterLevel = 0.9;
      painter.boatProgress = 0.5;
      painter.boatsObstructed = true;
      painter.highlightStakes = true;
      expect(notified, 4);
      // Same-value writes are no-ops — no repaint spam.
      painter.waterLevel = 0.9;
      expect(notified, 4);
      expect(painter.waterLevel, 0.9);
      expect(painter.boatsObstructed, isTrue);
    });
  });

  group('ReadRenderer + animationKey', () {
    testWidgets('known key renders the player above the reading card', (
      tester,
    ) async {
      await _pumpRead(tester, const {
        'text': 'Đoạn đọc.',
        'animationKey': 'bach_dang_938_tide_v1',
      }, onSubmit: (_) async {});
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsOneWidget);
      expect(find.text('Đoạn đọc.'), findsOneWidget);
    });

    testWidgets('unknown key falls back to plain READ — no crash', (
      tester,
    ) async {
      await _pumpRead(tester, const {
        'text': 'Chỉ đọc.',
        'animationKey': 'khong_co_scene_v1',
      }, onSubmit: (_) async {});
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsNothing);
      expect(find.text('Chỉ đọc.'), findsOneWidget);
    });

    testWidgets('missing animationKey renders READ unchanged', (tester) async {
      await _pumpRead(tester, const {
        'text': 'Đọc bình thường.',
      }, onSubmit: (_) async {});
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsNothing);
      expect(find.text('Đọc bình thường.'), findsOneWidget);
    });

    testWidgets('READ acknowledgement still submits {} with animation', (
      tester,
    ) async {
      Map<String, dynamic>? sent;
      await _pumpRead(tester, const {
        'text': 'x',
        'animationKey': 'bach_dang_938_tide_v1',
      }, onSubmit: (payload) async => sent = payload);
      await tester.pump();
      await _tap(tester, find.text('ĐÃ ĐỌC XONG, TIẾP TỤC'));
      expect(sent, isNotNull);
      expect(sent, isEmpty);
    });
  });

  group('HistoricalAnimationPlayer — Bạch Đằng 938', () {
    testWidgets('renders narration, disclaimer and source', (tester) async {
      await _pumpPlayer(tester);
      await tester.pump();
      expect(find.textContaining('Sơ đồ minh họa chiến thuật'), findsOneWidget);
      expect(find.textContaining('Bảo tàng Lịch sử Quốc gia'), findsOneWidget);
      expect(find.textContaining('Bước 1/6'), findsOneWidget);
    });

    testWidgets('slider updates the water level live', (tester) async {
      await _pumpPlayer(tester);
      await tester.pump();
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, closeTo(0.3, 0.01));

      // Kéo slider sang phải → mực nước tăng.
      await tester.ensureVisible(find.byType(Slider));
      await tester.pump();
      await tester.drag(find.byType(Slider), const Offset(200, 0));
      await tester.pump();
      final after = tester.widget<Slider>(find.byType(Slider));
      expect(after.value, greaterThan(0.3));
    });

    testWidgets('presets jump water level to rise/ebb values', (tester) async {
      await _pumpPlayer(tester);
      await tester.pump();
      await _tap(tester, find.widgetWithText(OutlinedButton, 'Nước rút'));
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(0.18, 0.001),
      );
      await _tap(tester, find.widgetWithText(OutlinedButton, 'Nước dâng'));
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(0.92, 0.001),
      );
    });

    testWidgets('next/prev buttons step through narration', (tester) async {
      await _pumpPlayer(tester);
      await tester.pump();
      expect(find.textContaining('Bước 1/6'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      expect(find.textContaining('Bước 2/6'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Bước trước'));
      expect(find.textContaining('Bước 1/6'), findsOneWidget);
    });

    testWidgets('play advances steps automatically then stops at last', (
      tester,
    ) async {
      await _pumpPlayer(tester);
      await tester.pump();
      await _tap(tester, find.text('PHÁT'));
      expect(find.text('TẠM DỪNG'), findsOneWidget);

      // Nhảy qua toàn bộ chuỗi: mỗi bước ~1.1s transition + 2.2s đọc.
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      expect(find.textContaining('Bước 6/6'), findsOneWidget);
      expect(find.text('PHÁT'), findsOneWidget); // auto-stop ở cuối
    });

    testWidgets('pause halts auto-advance', (tester) async {
      await _pumpPlayer(tester);
      await tester.pump();
      await _tap(tester, find.text('PHÁT'));
      await _tap(tester, find.text('TẠM DỪNG'));
      await tester.pump(const Duration(seconds: 6));
      // Vẫn ở bước 1 — không auto-next khi đang pause.
      expect(find.textContaining('Bước 1/6'), findsOneWidget);
    });

    testWidgets('replay returns to step 1 locally', (tester) async {
      await _pumpPlayer(tester);
      await tester.pump();
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      expect(find.textContaining('Bước 3/6'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Tua lại hoạt họa'));
      expect(find.textContaining('Bước 1/6'), findsOneWidget);
    });

    testWidgets('skip shows static summary and hides controls', (tester) async {
      await _pumpPlayer(tester);
      await tester.pump();
      await _tap(tester, find.text('Bỏ qua'));
      expect(
        find.textContaining('Đã bỏ qua phần minh họa tương tác'),
        findsOneWidget,
      );
      expect(find.byType(Slider), findsNothing);
      expect(find.textContaining('DỰ ĐOÁN'), findsNothing);
    });

    testWidgets('prediction feedback is local — never calls submit', (
      tester,
    ) async {
      Map<String, dynamic>? sent;
      await _pumpRead(tester, const {
        'text': 'x',
        'animationKey': 'bach_dang_938_tide_v1',
      }, onSubmit: (payload) async => sent = payload);
      await tester.pump();

      // Chọn phương án khớp cơ chế (B) rồi reveal.
      await _tap(tester, find.textContaining('Các cọc dần lộ ra'));
      await _tap(tester, find.text('XEM KẾT QUẢ VÀ GIẢI THÍCH'));
      expect(find.textContaining('đỉnh cọc nhô lên'), findsOneWidget);
      // Không submit nào được gọi.
      expect(sent, isNull);
    });

    testWidgets('prediction wrong option shows retry hint + explanation', (
      tester,
    ) async {
      await _pumpPlayer(tester);
      await tester.pump();
      await _tap(tester, find.textContaining('Các cọc vẫn chìm sâu'));
      await _tap(tester, find.text('XEM KẾT QUẢ VÀ GIẢI THÍCH'));
      expect(
        find.textContaining('Thử kéo mực nước xuống thấp'),
        findsOneWidget,
      );
    });

    testWidgets('reduced-motion renders steps without crash', (tester) async {
      await _pumpPlayer(tester, disableAnimations: true);
      await tester.pump();
      expect(find.textContaining('Bước 1/6'), findsOneWidget);
      await _tap(tester, find.text('PHÁT'));
      // Reduced-motion: nhảy tĩnh mỗi ~4s, không tween.
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
      expect(find.textContaining('Bước'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes cleanly when navigating away', (tester) async {
      await _pumpPlayer(tester);
      await tester.pump();
      await _tap(tester, find.text('PHÁT'));
      // Thay cây widget → dispose timer + controller không throw.
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a 320px-wide small screen without overflow', (
      tester,
    ) async {
      await _pumpPlayer(tester, surface: const Size(320, 700));
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('two players keep independent local state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(900, 1400)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    HistoricalAnimationPlayer(
                      key: const ValueKey('p1'),
                      definition: bachDang938TideV1,
                    ),
                    const Divider(),
                    HistoricalAnimationPlayer(
                      key: const ValueKey('p2'),
                      definition: bachDang938TideV1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Next trên player thứ nhất — player hai vẫn ở bước 1.
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      expect(find.textContaining('Bước 2/6'), findsOneWidget);
      expect(find.textContaining('Bước 1/6'), findsOneWidget);
    });
  });
}
