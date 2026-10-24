import 'package:dau_viet_mobile/features/learning/presentation/animations/content/bach_dang_938_tide_v1.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/content/hai_ba_trung_40_uprising_v1.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/historical_animation_definition.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/historical_animation_player.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/scenes/historical_map_scene.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/scenes/river_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  HistoricalAnimationDefinition? definition,
  bool disableAnimations = false,
  Size surface = const Size(800, 1400),
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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pump();
}

/// Lấy painter ra khỏi widget tree qua CustomPaint để assert state trực
/// tiếp (waterLevel/boatProgress/flags) — không chỉ qua Slider value.
/// Quét tất cả CustomPaint vì overlay/procedural glyph cũng dùng nó.
T _painterOf<T>(WidgetTester tester) {
  for (final cp in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    final p = cp.painter;
    if (p is T) return p as T;
  }
  throw StateError('không tìm thấy painter kiểu $T trong CustomPaint tree');
}

void main() {
  group('Playback state machine — reset contract', () {
    testWidgets('replay resets river painter to initial beat-0 state', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump();
      // Chạy tới cuối: settle end-state bằng Next x5 (không cần play).
      for (var i = 0; i < 5; i++) {
        await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
        await tester.pump(const Duration(milliseconds: 1400));
      }
      // Lúc này painter đang ở trạng thái cuối (obstructed, highlight,
      // summary, counterattack — bước 5 + 6).
      var p = _painterOf<RiverScenePainter>(tester);
      expect(p.showSequenceSummary, isTrue);
      expect(p.counterattackProgress, greaterThan(0));

      await _tap(tester, find.bySemanticsLabel('Tua lại hoạt họa'));
      await tester.pump(const Duration(milliseconds: 100));
      p = _painterOf<RiverScenePainter>(tester);
      // Frame ĐẦU beat 0 — initialState của scene: nước thấp, thuyền về
      // 0, không cờ nào bật. KHÔNG giữ trạng thái cuối trận.
      expect(
        p.waterLevel,
        closeTo(0.30, 0.01),
        reason: 'replay phải reset waterLevel về initialState',
      );
      expect(p.boatProgress, closeTo(0, 0.01));
      expect(p.boatsObstructed, isFalse);
      expect(p.highlightStakes, isFalse);
      expect(p.decoyProgress, 0);
      expect(p.counterattackProgress, 0);
      expect(p.showSequenceSummary, isFalse);
    });

    testWidgets('replay resets map painter markers + routes + focus', (
      tester,
    ) async {
      await _pump(tester, definition: haiBaTrung40UprisingV1);
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
        await tester.pump(const Duration(milliseconds: 1400));
      }
      var p = _painterOf<MapScenePainter>(tester);
      expect(p.markerVisibility.values.any((v) => v > 0.5), isTrue);
      expect(p.routeProgress.values.any((v) => v > 0.5), isTrue);
      expect(p.highlightedIds, isNotEmpty);

      await _tap(tester, find.bySemanticsLabel('Tua lại hoạt họa'));
      await tester.pump(const Duration(milliseconds: 100));
      p = _painterOf<MapScenePainter>(tester);
      // Beat 0 của scene map: chưa marker nào hiện (target rỗng).
      expect(p.markerVisibility.values.every((v) => v <= 0.02), isTrue);
      expect(p.routeProgress.values.every((v) => v <= 0.02), isTrue);
      expect(p.highlightedIds, isEmpty);
      expect(p.focusedId, isNull);
    });
  });

  group('Playback state machine — last-step semantics', () {
    testWidgets('pause on last step then Play resumes last step', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump();
      // Vào bước cuối bằng Next x5 — vẫn paused (idle), chưa finish.
      for (var i = 0; i < 5; i++) {
        await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
        await tester.pump(const Duration(milliseconds: 1400));
      }
      expect(find.textContaining('Bước 6/6'), findsOneWidget);

      // Play → pause ngay (đang ở bước cuối) → phải RESUME bước cuối,
      // KHÔNG được replay về beat 0.
      await _tap(tester, find.text('PHÁT'));
      await _tap(tester, find.text('TẠM DỪNG'));
      await _tap(tester, find.text('PHÁT'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Bước 6/6'), findsOneWidget);
      // Dọn timer.
      await _tap(tester, find.text('TẠM DỪNG'));
    });

    testWidgets('finished (AUTO ran out) then Play replays from start', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump();
      await _tap(tester, find.text('PHÁT'));
      // Dừng ở checkpoint (bước 3) → giải → chạy tới cuối.
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      await _tap(tester, find.textContaining('Các cọc dần lộ ra'));
      await _tap(tester, find.text('XEM KẾT QUẢ VÀ GIẢI THÍCH'));
      await _tap(tester, find.text('PHÁT'));
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      // Đã hết scene — UI hiện PHÁT (auto-stop).
      expect(find.textContaining('Bước 6/6'), findsOneWidget);
      expect(find.text('PHÁT'), findsOneWidget);

      // Play sau finish = replay từ đầu (contract FINISHED → Play).
      await _tap(tester, find.text('PHÁT'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Bước 1/6'), findsOneWidget);
      // Đang phát lại → TẠM DỪNG hiện.
      expect(find.text('TẠM DỪNG'), findsOneWidget);
      await _tap(tester, find.text('TẠM DỪNG'));
    });
  });

  group('Playback state machine — single-step scene', () {
    HistoricalAnimationDefinition singleStep() => HistoricalAnimationDefinition(
      key: 'single_step_test',
      title: 'Test một bước',
      learningObjective: 'x',
      disclaimer: 'd',
      sourceReference: 's',
      hasWaterControl: true,
      transitionDuration: const Duration(milliseconds: 400),
      createPainter: RiverScenePainter.new,
      steps: const [
        HistoricalAnimationStep(
          label: 'Duy nhất',
          narration: 'Bước duy nhất của scene.',
          target: RiverSceneState(waterLevel: 0.9, boatProgress: 0.5),
        ),
      ],
    );

    testWidgets('single-step scene: mount/play/pause/resume/finish/replay '
        'không crash, không index out of range', (tester) async {
      await _pump(tester, definition: singleStep());
      await tester.pump();
      expect(find.textContaining('Bước 1/1'), findsOneWidget);
      // Play → TẠM DỪNG → PHÁT (resume cùng bước, không replay về 0 vì
      // đang ở bước duy nhất chưa finish).
      await _tap(tester, find.text('PHÁT'));
      await _tap(tester, find.text('TẠM DỪNG'));
      await _tap(tester, find.text('PHÁT'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Bước 1/1'), findsOneWidget);
      // Replay + skip đều an toàn.
      await _tap(tester, find.bySemanticsLabel('Tua lại hoạt họa'));
      await _tap(tester, find.text('Bỏ qua'));
      expect(tester.takeException(), isNull);
    });
  });

  group('Playback state machine — manual interaction hold', () {
    testWidgets('manual water then Play does NOT resume/settle tween', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump();
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byType(Slider));
      await tester.drag(find.byType(Slider), const Offset(-150, 0));
      await tester.pump();
      final manual = tester.widget<Slider>(find.byType(Slider)).value;

      // Play → giữ giá trị learner (không trôi về target 0.90, không
      // resume tween đã hủy).
      await _tap(tester, find.text('PHÁT'));
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(manual, 0.01),
      );
      await _tap(tester, find.text('TẠM DỪNG'));
    });
  });

  group('Playback state machine — replay then play restarts', () {
    testWidgets('replay while paused then Play starts from beat 0', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump();
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      // Replay lúc paused = seek tĩnh về đầu (không tự phát).
      await _tap(tester, find.bySemanticsLabel('Tua lại hoạt họa'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Bước 1/6'), findsOneWidget);
      expect(find.text('PHÁT'), findsOneWidget); // vẫn paused
      // Play → bắt đầu beat 0 (không phải resume mid).
      await _tap(tester, find.text('PHÁT'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('TẠM DỪNG'), findsOneWidget);
      await _tap(tester, find.text('TẠM DỪNG'));
    });
  });
}
