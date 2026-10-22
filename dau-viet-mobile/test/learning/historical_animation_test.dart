import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/content/bach_dang_938_tide_v1.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/content/hai_ba_trung_40_uprising_v1.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/content/ly_thai_to_1010_relocation_v1.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/historical_animation_definition.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/historical_animation_player.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/historical_animation_registry.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/scenes/historical_map_scene.dart';
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

    test('resolves both ANIM-02 map scenes', () {
      final hbt = HistoricalAnimationRegistry.resolve(
        'hai_ba_trung_40_uprising_v1',
      );
      final ltt = HistoricalAnimationRegistry.resolve(
        'ly_thai_to_1010_relocation_v1',
      );
      expect(hbt, isNotNull);
      expect(ltt, isNotNull);
      expect(hbt!.createPainter(), isA<MapScenePainter>());
      expect(ltt!.createPainter(), isA<MapScenePainter>());
      expect(hbt.hasLocationExplorer, isTrue);
      expect(ltt.hasLocationExplorer, isTrue);
      // Không tái dùng water control của river.
      expect(hbt.hasWaterControl, isFalse);
      expect(ltt.hasWaterControl, isFalse);
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

  group('RiverScenePainter — stake geometry', () {
    const canvas = Size(800, 500); // khớp AspectRatio 16/10 ở width 800

    test('low water exposes stake tips above the waterline', () {
      // Step 1/4 target ≈0.28-0.30: một số ngọn cọc phải NHÔ lên —
      // canvas y tăng xuống, tip.dy < surfaceY mới là exposed.
      final surfaceY = RiverScenePainter.waterSurfaceYFor(500, 0.30);
      var exposed = 0;
      for (var i = 0; i < 9; i++) {
        final tipY = RiverScenePainter.stakeTipFor(canvas, i).dy;
        expect(
          RiverScenePainter.stakeTipExposed(tipY, surfaceY),
          tipY < surfaceY,
        );
        if (tipY < surfaceY) exposed++;
      }
      expect(exposed, greaterThan(0));
      expect(RiverScenePainter.exposedTipCount(canvas, 0.30), exposed);
    });

    test('high water submerges every stake tip', () {
      // waterLevel 0.90: không ngọn nào được lộ.
      expect(RiverScenePainter.exposedTipCount(canvas, 0.90), 0);
      final surfaceY = RiverScenePainter.waterSurfaceYFor(500, 0.90);
      for (var i = 0; i < 9; i++) {
        final tipY = RiverScenePainter.stakeTipFor(canvas, i).dy;
        expect(RiverScenePainter.stakeTipExposed(tipY, surfaceY), isFalse);
      }
    });

    test('raising water never increases the exposed-tip count', () {
      var prev = 99;
      for (var wl = 0.0; wl <= 1.001; wl += 0.05) {
        final count = RiverScenePainter.exposedTipCount(canvas, wl);
        expect(
          count,
          lessThanOrEqualTo(prev),
          reason: 'waterLevel $wl exposed $count > previous $prev',
        );
        prev = count;
      }
    });

    test('every stake base sits on the drawn riverbed', () {
      final bedTop = RiverScenePainter.bedTopFor(500);
      for (var i = 0; i < 9; i++) {
        expect(
          RiverScenePainter.stakeBaseFor(canvas, i).dy,
          closeTo(bedTop, 0.001),
          reason: 'stake $i base detached from riverbed',
        );
      }
    });

    test('stake geometry stays inside normalized canvas bounds', () {
      for (var i = 0; i < 9; i++) {
        final tip = RiverScenePainter.stakeTipFor(canvas, i);
        final base = RiverScenePainter.stakeBaseFor(canvas, i);
        expect(base.dx, inInclusiveRange(0, 800));
        expect(base.dy, lessThanOrEqualTo(500));
        expect(tip.dy, greaterThan(0), reason: 'stake $i tip off-canvas');
        expect(tip.dy, lessThan(base.dy), reason: 'stake $i inverted');
      }
    });
  });

  group('RiverScenePainter — boat path continuity', () {
    const w = 800.0;

    test('obstruction never shifts a boat horizontally', () {
      // boatsObstructed là cờ trình bày: display X phải ĐỒNG NHẤT path X
      // ở mọi lane/progress — bật cờ không teleport theo cả hai chiều.
      for (var lane = 0; lane < 3; lane++) {
        for (var p = 0.0; p <= 1.001; p += 0.05) {
          final free = RiverScenePainter.boatXFor(w, p, lane);
          final blocked = RiverScenePainter.boatDisplayXFor(w, p, lane, true);
          expect(
            blocked,
            closeTo(free, 0.001),
            reason: 'lane $lane p=$p: $blocked != $free',
          );
        }
      }
    });

    test('toggling obstruction never moves the boat position', () {
      // Kịch bản step 4→5: bật obstructed ở mọi điểm trên đường đi đều
      // giữ nguyên X — không jump dù thuyền còn ngoài hay đã vào bãi.
      for (var lane = 0; lane < 3; lane++) {
        for (var p = 0.0; p <= 1.001; p += 0.02) {
          final before = RiverScenePainter.boatDisplayXFor(w, p, lane, false);
          final after = RiverScenePainter.boatDisplayXFor(w, p, lane, true);
          expect(
            (after - before).abs(),
            lessThan(0.001),
            reason: 'lane $lane jumped ${after - before}px at p=$p',
          );
        }
      }
    });

    test('final progress lands the lead boat inside the stake field', () {
      // boatProgress 0.85 của step 3→5: thuyền đầu phải nằm TRONG khu vực
      // bãi cọc (0.42w..0.65w) — trực quan "mắc cọc", không phải đã qua
      // hẳn hay còn ngoài khơi.
      final x = RiverScenePainter.boatXFor(w, 0.85, 0);
      expect(x, greaterThan(w * 0.42));
      expect(x, lessThan(RiverScenePainter.stakeFieldEdgeX(w)));
    });

    test('steps 3-5 keep a coherent boat position inside the scene', () {
      // boatProgress 0.85 ở step 3→5: vị trí trong canvas và X giữ
      // NGUYÊN khi obstruction bật — không jump, không nhảy lùi.
      final xFree = RiverScenePainter.boatXFor(w, 0.85, 0);
      final xBlocked = RiverScenePainter.boatDisplayXFor(w, 0.85, 0, true);
      expect(xFree, inInclusiveRange(0, w));
      expect(xBlocked, inInclusiveRange(0, w));
      expect(xBlocked, closeTo(xFree, 0.001));
    });

    test('water level never shifts boats horizontally', () {
      // Display X phụ thuộc progress/lane/obstruction — KHÔNG phụ thuộc
      // mực nước; đổi nước chỉ đổi y (thuyền nổi theo mặt nước).
      final low = RiverScenePainter.boatDisplayXFor(w, 0.85, 0, true);
      final high = RiverScenePainter.boatDisplayXFor(w, 0.85, 0, true);
      expect(low, high);
      // Mực nước đổi → y thuyền đổi theo surfaceY.
      final yLow = RiverScenePainter.waterSurfaceYFor(500, 0.28);
      final yHigh = RiverScenePainter.waterSurfaceYFor(500, 0.90);
      expect(yLow, greaterThan(yHigh)); // y tăng xuống: nước rút thấp hơn
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

    testWidgets('pause freezes an in-flight tween; resume continues', (
      tester,
    ) async {
      await _pumpPlayer(tester);
      await tester.pump();
      // Nhảy tới step 2 → tween nước bắt đầu (0.30 → 0.90).
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      await tester.pump(const Duration(milliseconds: 400)); // tween giữa chừng
      final mid = tester.widget<Slider>(find.byType(Slider)).value;
      expect(mid, greaterThan(0.3));
      expect(mid, lessThan(0.9));

      // PHÁT rồi TẠM DỪNG ngay khi tween đang chạy.
      await _tap(tester, find.text('PHÁT'));
      await _tap(tester, find.text('TẠM DỪNG'));
      final frozen = tester.widget<Slider>(find.byType(Slider)).value;
      await tester.pump(const Duration(milliseconds: 900));
      // Tween đã đóng băng — slider không trôi thêm.
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(frozen, 0.001),
      );

      // RESUME: tiếp tục an toàn — không nhảy về 0.3, không reset.
      await _tap(tester, find.text('PHÁT'));
      await tester.pump(const Duration(milliseconds: 800));
      final resumed = tester.widget<Slider>(find.byType(Slider)).value;
      expect(resumed, greaterThanOrEqualTo(frozen));
    });

    testWidgets('play after a manual water change does not resume the '
        'abandoned tween', (tester) async {
      await _pumpPlayer(tester);
      await tester.pump();
      // Step 2: tween nước 0.30 → 0.90 đang chạy; learner kéo slider tay
      // giữa chừng → tween bị HỦY (controller.value dở dang 0..1).
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byType(Slider));
      await tester.drag(find.byType(Slider), const Offset(-150, 0));
      await tester.pump();
      final manual = tester.widget<Slider>(find.byType(Slider)).value;
      expect(manual, lessThan(0.9));

      // Bấm PHÁT: KHÔNG được nối tiếp tween đã hủy — mực nước giữ giá trị
      // learner chọn, không trôi về 0.90.
      await _tap(tester, find.text('PHÁT'));
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(manual, 0.01),
      );
      // TẠM DỪNG lại để dọn timer cho teardown.
      await _tap(tester, find.text('TẠM DỪNG'));
    });

    testWidgets('play after prediction reveal keeps the revealed scene', (
      tester,
    ) async {
      await _pumpPlayer(tester);
      await tester.pump();
      // Tween step 2 đang chạy; reveal hủy tween + ép nước rút 0.22.
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      await tester.pump(const Duration(milliseconds: 300));
      await _tap(tester, find.textContaining('Các cọc dần lộ ra'));
      await _tap(tester, find.text('XEM KẾT QUẢ VÀ GIẢI THÍCH'));
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(0.22, 0.01),
      );

      // Bấm PHÁT: không được resume tween cũ kéo nước lên 0.90 lần nữa.
      await _tap(tester, find.text('PHÁT'));
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(0.22, 0.01),
      );
      await _tap(tester, find.text('TẠM DỪNG'));
    });

    testWidgets('replay clears prediction selection and revealed state', (
      tester,
    ) async {
      await _pumpPlayer(tester);
      await tester.pump();
      // Chọn + reveal prediction.
      await _tap(tester, find.textContaining('Các cọc dần lộ ra'));
      await _tap(tester, find.text('XEM KẾT QUẢ VÀ GIẢI THÍCH'));
      expect(find.textContaining('đỉnh cọc nhô lên'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Tua lại hoạt họa'));
      // Về bước 1 + nước ban đầu + câu hỏi chưa trả lời quay lại.
      expect(find.textContaining('Bước 1/6'), findsOneWidget);
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(0.3, 0.01),
      );
      expect(find.text('XEM KẾT QUẢ VÀ GIẢI THÍCH'), findsOneWidget);
      expect(find.textContaining('đỉnh cọc nhô lên'), findsNothing);
    });

    testWidgets('reveal during an active tween is not overwritten', (
      tester,
    ) async {
      await _pumpPlayer(tester);
      await tester.pump();
      // Vào step 3 (tween đang đẩy thuyền + nước cao).
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      await tester.pump(const Duration(milliseconds: 300));

      // Reveal ngay khi tween đang chạy.
      await _tap(tester, find.textContaining('Các cọc dần lộ ra'));
      await _tap(tester, find.text('XEM KẾT QUẢ VÀ GIẢI THÍCH'));
      final revealed = tester.widget<Slider>(find.byType(Slider)).value;
      expect(revealed, closeTo(0.22, 0.01));

      // Tween cũ không được phép kéo nước trở lại target của step.
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(0.22, 0.01),
      );
    });

    testWidgets('manual slider wins over an in-flight step tween', (
      tester,
    ) async {
      await _pumpPlayer(tester);
      await tester.pump();
      // Step 2 tween nước lên 0.90; kéo tay xuống giữa chừng.
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byType(Slider));
      await tester.drag(find.byType(Slider), const Offset(-150, 0));
      await tester.pump();
      final manual = tester.widget<Slider>(find.byType(Slider)).value;
      expect(manual, lessThan(0.9));
      // Tween phải dừng — không tự kéo lại về 0.90.
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(manual, 0.01),
      );
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

    // Màn hình nhỏ thật: dùng tester.view (kích thước physical +
    // devicePixelRatio) thay vì MediaQuery giả — bắt được overflow
    // render thực sự. Mỗi case phải restore view trong teardown.
    for (final logicalWidth in <double>[320, 360, 390]) {
      testWidgets('fits a ${logicalWidth}logical-px screen without overflow', (
        tester,
      ) async {
        const dpr = 3.0;
        const logicalHeight = 800.0;
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = Size(
          logicalWidth * dpr,
          logicalHeight * dpr,
        );
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HistoricalAnimationPlayer(definition: bachDang938TideV1),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(HistoricalAnimationPlayer), findsOneWidget);
        // RenderFlex overflow sẽ ném exception trong pump.
        expect(tester.takeException(), isNull);
        // Toàn bộ nội dung phải nằm trong bề rộng logical.
        final playerBox = tester.getRect(
          find.byType(HistoricalAnimationPlayer),
        );
        expect(playerBox.left, greaterThanOrEqualTo(0));
        expect(playerBox.right, lessThanOrEqualTo(logicalWidth));
      });
    }

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

  group('MapScenePainter — model & geometry', () {
    MapScenePainter painterOf(HistoricalAnimationDefinition def) =>
        def.createPainter() as MapScenePainter;

    test('both scenes have valid internal model references', () {
      for (final def in [haiBaTrung40UprisingV1, lyThaiTo1010RelocationV1]) {
        final p = painterOf(def);
        expect(
          MapScenePainter.validateModel(p.locations, p.routes),
          isEmpty,
          reason: '${def.key} has invalid model',
        );
        // Mọi location id được step tham chiếu phải tồn tại.
        final ids = p.locations.map((l) => l.id).toSet();
        for (final step in def.steps) {
          final t = step.target;
          if (t is MapSceneState) {
            for (final id in t.markerVisibility.keys) {
              expect(ids, contains(id), reason: '${def.key} step "$id"');
            }
            for (final id in t.highlighted) {
              expect(ids, contains(id));
            }
            if (t.focusedId != null) {
              expect(ids, contains(t.focusedId));
            }
          }
        }
      }
    });

    test('marker positions stay inside normalized bounds', () {
      for (final def in [haiBaTrung40UprisingV1, lyThaiTo1010RelocationV1]) {
        final p = painterOf(def);
        for (final loc in p.locations) {
          expect(loc.position.dx, inInclusiveRange(0, 1));
          expect(loc.position.dy, inInclusiveRange(0, 1));
          final px = MapScenePainter.positionOf(
            p.locations,
            loc.id,
            const Size(640, 400),
          );
          expect(px, isNotNull);
          expect(px!.dx, inInclusiveRange(0, 640));
          expect(px.dy, inInclusiveRange(0, 400));
        }
      }
    });

    test('route progress lerps monotonically toward the target', () {
      final p = painterOf(haiBaTrung40UprisingV1);
      const target = MapSceneState(
        markerVisibility: {'hat_mon': 1, 'me_linh': 1},
        routeProgress: {'gather': 1},
      );
      var prev = -1.0;
      for (var t = 0.0; t <= 1.001; t += 0.1) {
        target.apply(p, t);
        final v = p.routeProgress['gather']!;
        expect(v, greaterThanOrEqualTo(prev - 0.001));
        prev = v;
      }
      expect(p.routeProgress['gather'], closeTo(1, 0.001));
      expect(p.markerVisibility['me_linh'], closeTo(1, 0.001));
    });

    test('route point interpolation is stable at both ends', () {
      final p = painterOf(lyThaiTo1010RelocationV1);
      final route = p.routes.first;
      final start = MapScenePainter.routePointAt(route, p.locations, 0);
      final end = MapScenePainter.routePointAt(route, p.locations, 1);
      final hoaLu = p.locations.firstWhere((l) => l.id == 'hoa_lu');
      final daiLa = p.locations.firstWhere((l) => l.id == 'dai_la');
      expect(start.dx, closeTo(hoaLu.position.dx, 0.001));
      expect(start.dy, closeTo(hoaLu.position.dy, 0.001));
      expect(end.dx, closeTo(daiLa.position.dx, 0.001));
      expect(end.dy, closeTo(daiLa.position.dy, 0.001));
    });

    test('MapScene does not misuse river state fields', () {
      // Map painter KHÔNG override setter river — ghi vào đó không đổi
      // trạng thái map, chứng minh không lạm dụng biến của scene khác.
      final p = painterOf(haiBaTrung40UprisingV1);
      p.waterLevel = 0.9;
      p.boatProgress = 0.9;
      p.boatsObstructed = true;
      expect(p.markerVisibility, isEmpty);
      expect(p.routeProgress, isEmpty);
      expect(p.highlightedIds, isEmpty);
    });
  });

  group('HistoricalAnimationPlayer — Map scenes (ANIM-02)', () {
    testWidgets('Hai Ba Trung renders narration, disclaimer and source', (
      tester,
    ) async {
      await _pumpPlayer(tester, definition: haiBaTrung40UprisingV1);
      await tester.pump();
      expect(find.textContaining('Bước 1/6'), findsOneWidget);
      expect(find.textContaining('Bản đồ minh họa schematic'), findsOneWidget);
      expect(find.textContaining('Bảo tàng Lịch sử Quốc gia'), findsOneWidget);
      // Không có slider nước của river scene.
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('Lý Thái Tổ renders 5 steps and disclaimer', (tester) async {
      await _pumpPlayer(tester, definition: lyThaiTo1010RelocationV1);
      await tester.pump();
      expect(find.textContaining('Bước 1/5'), findsOneWidget);
      expect(find.textContaining('Hoa Lư'), findsWidgets);
      expect(find.textContaining('schematic'), findsOneWidget);
    });

    testWidgets('next/prev updates map steps', (tester) async {
      await _pumpPlayer(tester, definition: haiBaTrung40UprisingV1);
      await tester.pump();
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      expect(find.textContaining('Bước 2/6'), findsOneWidget);
      expect(
        find.textContaining('Khởi nghĩa bùng lên'.toUpperCase()),
        findsOneWidget,
      );
      await _tap(tester, find.bySemanticsLabel('Bước trước'));
      expect(find.textContaining('Bước 1/6'), findsOneWidget);
    });

    testWidgets('tapping a marker shows its historical explanation', (
      tester,
    ) async {
      await _pumpPlayer(tester, definition: haiBaTrung40UprisingV1);
      await tester.pump();
      // Vào bước 5 (Khám phá) — mọi marker đã hiện.
      for (var i = 0; i < 4; i++) {
        await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      }
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.textContaining('Bước 5/6'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Địa điểm Hát Môn'));
      expect(find.textContaining('sông Hát / Hát Môn'), findsOneWidget);
      expect(find.textContaining('Nơi phát khởi'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Địa điểm Mê Linh'));
      expect(find.textContaining('quê hương và nơi quy tụ'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Địa điểm Luy Lâu'));
      expect(find.textContaining('nhà Đông Hán ở Giao Chỉ'), findsOneWidget);
      expect(find.textContaining('Trung tâm Hán'), findsOneWidget);
    });

    testWidgets('tapping Hoa Lư and Đại La shows their roles', (tester) async {
      await _pumpPlayer(tester, definition: lyThaiTo1010RelocationV1);
      await tester.pump();
      // Step cuối — cả 2 marker hiện.
      for (var i = 0; i < 4; i++) {
        await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      }
      await tester.pump(const Duration(milliseconds: 1200));

      await _tap(tester, find.bySemanticsLabel('Địa điểm Hoa Lư'));
      expect(find.textContaining('kinh đô của các triều Đinh'), findsOneWidget);
      expect(find.textContaining('Kinh đô cũ'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Địa điểm Đại La — Thăng Long'));
      expect(find.textContaining('CÙNG một địa điểm'), findsOneWidget);
    });

    testWidgets('replay clears marker selection and resets scene', (
      tester,
    ) async {
      await _pumpPlayer(tester, definition: haiBaTrung40UprisingV1);
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      }
      await tester.pump(const Duration(milliseconds: 1200));
      await _tap(tester, find.bySemanticsLabel('Địa điểm Luy Lâu'));
      // Panel giải thích của Luy Lâu đang mở.
      expect(find.textContaining('nhà Đông Hán ở Giao Chỉ'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Tua lại hoạt họa'));
      expect(find.textContaining('Bước 1/6'), findsOneWidget);
      // Panel đã đóng — không giữ selection cũ.
      expect(find.textContaining('nhà Đông Hán ở Giao Chỉ'), findsNothing);
    });

    testWidgets('prediction reveal highlights Luy Lâu on the map', (
      tester,
    ) async {
      await _pumpPlayer(tester, definition: haiBaTrung40UprisingV1);
      await tester.pump();
      await _tap(
        tester,
        find.textContaining('trung tâm hành chính của nhà Hán'),
      );
      await _tap(tester, find.text('XEM KẾT QUẢ VÀ GIẢI THÍCH'));
      expect(
        find.textContaining('thách thức trực tiếp đến bộ máy cai trị'),
        findsOneWidget,
      );
    });

    testWidgets('pause freezes a map transition; resume continues', (
      tester,
    ) async {
      await _pumpPlayer(tester, definition: lyThaiTo1010RelocationV1);
      await tester.pump();
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      await tester.pump(const Duration(milliseconds: 300));
      // Tween đang chạy: PHÁT → TẠM DỪNG ngay.
      await _tap(tester, find.text('PHÁT'));
      await _tap(tester, find.text('TẠM DỪNG'));
      await tester.pump(const Duration(milliseconds: 800));
      // Không auto-advance khi pause.
      expect(find.textContaining('Bước 2/5'), findsOneWidget);
      // Resume — không nhảy step, không crash.
      await _tap(tester, find.text('PHÁT'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await _tap(tester, find.text('TẠM DỪNG'));
    });

    testWidgets('skip hides map controls and never submits', (tester) async {
      Map<String, dynamic>? sent;
      await _pumpRead(tester, const {
        'text': 'x',
        'animationKey': 'hai_ba_trung_40_uprising_v1',
      }, onSubmit: (payload) async => sent = payload);
      await tester.pump();
      await _tap(tester, find.text('Bỏ qua'));
      expect(
        find.textContaining('Đã bỏ qua phần minh họa tương tác'),
        findsOneWidget,
      );
      expect(sent, isNull);
      // READ ack vẫn submit {} như thường.
      await _tap(tester, find.text('ĐÃ ĐỌC XONG, TIẾP TỤC'));
      expect(sent, isEmpty);
    });

    testWidgets('prediction is local — never calls submit', (tester) async {
      Map<String, dynamic>? sent;
      await _pumpRead(tester, const {
        'text': 'x',
        'animationKey': 'ly_thai_to_1010_relocation_v1',
      }, onSubmit: (payload) async => sent = payload);
      await tester.pump();
      await _tap(tester, find.textContaining('Đại La — sau này mang tên'));
      await _tap(tester, find.text('XEM KẾT QUẢ VÀ GIẢI THÍCH'));
      expect(find.textContaining('Thăng Long'), findsWidgets);
      expect(sent, isNull);
    });

    testWidgets('map scene fits 320/360/390 without overflow', (tester) async {
      for (final logicalWidth in <double>[320, 360, 390]) {
        const dpr = 3.0;
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = Size(logicalWidth * dpr, 800 * dpr);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HistoricalAnimationPlayer(
                  definition: haiBaTrung40UprisingV1,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(HistoricalAnimationPlayer), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });

    testWidgets('reduced-motion renders map end states immediately', (
      tester,
    ) async {
      await _pumpPlayer(
        tester,
        definition: haiBaTrung40UprisingV1,
        disableAnimations: true,
      );
      await tester.pump();
      await _tap(tester, find.bySemanticsLabel('Bước tiếp'));
      expect(find.textContaining('Bước 2/6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
