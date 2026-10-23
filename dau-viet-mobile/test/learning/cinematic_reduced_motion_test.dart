import 'package:dau_viet_mobile/features/learning/presentation/animations/historical_animation_player.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/runtime/animation_manifest_dto.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/runtime/cinematic_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// V16 — reduced-motion cho manifest v2 (camera/tracks/effects/audio):
/// với `disableAnimations=true`, player phải nhảy tĩnh tới frame cuối
/// mỗi bước (camera/keyframes không tween), không crash, vẫn auto-advance
/// theo nhịp 4s.
///
/// Dùng manifest JSON inline (không fetch asset) — fixture V16 chuẩn
/// nằm ở `dau-viet-backend/src/test/resources/animation-manifests/` và
/// đã được `AnimationManifestValidatorTest` kiểm chứng ở backend.

Map<String, dynamic> _bachDangV2() => {
      'schemaVersion': 2,
      'rendererCode': 'RIVER_TIDE',
      'rendererVersion': 1,
      'title': 'Bạch Đằng 938 — Cinematic',
      'disclaimer': 'Minh họa schematic.',
      'sourceReferences': [
        {'title': 'BTLSQG'}
      ],
      'canvas': {'aspectRatio': 1.6},
      'objects': [
        {
          'id': 'boat-decoy',
          'type': 'BOAT',
          'position': {'x': 0.15, 'y': 0.45},
          'scale': 0.14,
          'layer': 1,
          'visible': true,
          'rotation': 0,
          'opacity': 1,
        },
      ],
      'river': {
        'stakes': [
          {'id': 'stake-1', 'x': 0.42, 'length': 0.20},
          {'id': 'stake-2', 'x': 0.55, 'length': 0.22},
        ],
      },
      'environment': {'mist': 0.35, 'glow': 0.2},
      'camera': {
        'initial': {'x': 0.5, 'y': 0.5, 'zoom': 1.0},
        'steps': [
          {'target': {'x': 0.5, 'y': 0.5, 'zoom': 1.0}},
          {'target': {'x': 0.55, 'y': 0.55, 'zoom': 1.6}},
          {'target': {'x': 0.5, 'y': 0.5, 'zoom': 1.0}},
        ],
      },
      'tracks': [
        {
          'objectId': 'boat-decoy',
          'property': 'position',
          'keyframes': [
            {'tMs': 0, 'value': {'x': 0.15, 'y': 0.45}, 'easing': 'linear'},
            {'tMs': 2200, 'value': {'x': 0.62, 'y': 0.40}, 'easing': 'linear'},
            {'tMs': 4400, 'value': {'x': 0.62, 'y': 0.40}, 'easing': 'linear'},
          ],
        },
      ],
      'effects': [
        {
          'type': 'WATER_RIPPLE',
          'stepId': 'tide-fall',
          'durationMs': 2200,
          'params': {'x': 0.55, 'y': 0.62, 'intensity': 0.7},
        },
      ],
      'audio': [],
      'interactions': ['WATER_LEVEL_CONTROL', 'PREDICTION'],
      'initialState': {},
      'steps': [
        {
          'id': 'prepare',
          'title': 'Chuẩn bị',
          'durationMs': 1100,
          'targetState': {'waterLevel': 0.30},
        },
        {
          'id': 'tide-fall',
          'title': 'Nước rút',
          'durationMs': 1100,
          'targetState': {'waterLevel': 0.28, 'boatProgress': 0.85},
        },
        {
          'id': 'summary',
          'title': 'Tổng kết',
          'durationMs': 1100,
          'targetState': {'waterLevel': 0.28},
        },
      ],
    };

/// ManifestAssetLayers không được bọc ở đây — test tập trung vào player
/// + CinematicFrame (ValueNotifier) chứ không render ảnh (assets rỗng).
Widget _wrap(AnimationManifestDto manifest, ValueNotifier<CinematicFrame> frame) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(800, 1200),
        disableAnimations: true, // <-- reduced-motion
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          child: HistoricalAnimationPlayer(
            definition: manifest.toDefinition(),
            manifest: manifest,
            cinematicFrame: frame,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('V16 reduced-motion (MediaQuery.disableAnimations)', () {
    testWidgets(
        'player init emits final frame of step 0 — no tween started',
        (tester) async {
      final manifest = AnimationManifestDto.fromJson(_bachDangV2());
      final frame = ValueNotifier(
        CinematicFrame(camera: manifest.cinematic.cameraInitial),
      );
      addTearDown(frame.dispose);

      await tester.pumpWidget(_wrap(manifest, frame));
      await tester.pump();

      // Step 0 camera target = (0.5, 0.5, zoom 1.0) — frame phải khớp
      // đích, không phải frame trung gian. CinematicFrame được emit qua
      // `_emitFrameEnd` vì reduced-motion không chạy controller.
      expect(frame.value.camera.zoom, closeTo(1.0, 1e-6));
      expect(frame.value.camera.center.dx, closeTo(0.5, 1e-6));
      expect(frame.value.camera.center.dy, closeTo(0.5, 1e-6));
      // Track keyframes: `frameEndAt(0)` đánh giá tại cuối step 0 —
      // step.durationMs=1100 nằm GIỮA keyframe t=0 (0.15) và t=2200 (0.62)
      // → giá trị nội suy tĩnh: x ≈ 0.15 + (0.62-0.15)*1100/2200 = 0.385.
      // Đây đúng contract reduced-motion: nhảy tới END-STATE của bước,
      // không phải tMs=0 toàn cục.
      final boat = frame.value.objects['boat-decoy'];
      expect(boat, isNotNull);
      expect(boat!.position.dx, closeTo(0.385, 1e-3));
      expect(boat.position.dy, closeTo(0.425, 1e-3));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'auto-advance jumps camera+track to each step end state (no tween)',
        (tester) async {
      final manifest = AnimationManifestDto.fromJson(_bachDangV2());
      final frame = ValueNotifier(
        CinematicFrame(camera: manifest.cinematic.cameraInitial),
      );
      addTearDown(frame.dispose);

      await tester.pumpWidget(_wrap(manifest, frame));
      await tester.pump();
      // Bấm PHÁT → nhảy tĩnh theo nhịp 4s/bước (không tween).
      await tester.ensureVisible(find.text('PHÁT').first);
      await tester.tap(find.text('PHÁT').first);
      await tester.pump();

      // Qua bước 1 ('tide-fall'): camera phải NHẢY tới (0.55,0.55,1.6),
      // track boat-decoy tới keyframe cuối (0.62,0.40). Không có frame
      // trung gian vì controller không chạy.
      await tester.pump(const Duration(milliseconds: 4500));
      await tester.pump();
      expect(frame.value.camera.zoom, greaterThan(1.4));
      expect(frame.value.camera.zoom, lessThanOrEqualTo(1.6));
      final boat1 = frame.value.objects['boat-decoy'];
      expect(boat1!.position.dx, closeTo(0.62, 0.05));

      // Qua bước cuối ('summary'): camera về (0.5,0.5,1.0).
      await tester.pump(const Duration(milliseconds: 4500));
      await tester.pump();
      expect(frame.value.camera.zoom, closeTo(1.0, 1e-6));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'map-manifest v2 (no camera steps) still renders + advances safely',
        (tester) async {
      // Scene map tối thiểu — không camera/tracks nhưng vẫn schemaVersion=2
      // (nhánh `_hasCinematic` phải là false → không emit frame nào).
      final mapManifest = AnimationManifestDto.fromJson({
        'schemaVersion': 2,
        'rendererCode': 'JOURNEY_MAP',
        'rendererVersion': 1,
        'title': 'Hai Bà Trưng — Cinematic tối thiểu',
        'disclaimer': 'Minh họa schematic.',
        'sourceReferences': [
          {'title': 'BTLSQG'}
        ],
        'map': {
          'locations': [
            {'id': 'a', 'name': 'A', 'x': 0.3, 'y': 0.6},
            {'id': 'b', 'name': 'B', 'x': 0.7, 'y': 0.4},
          ],
          'routes': [
            {'id': 'r', 'from': 'a', 'to': 'b'},
          ],
        },
        'effects': [
          {'type': 'FADE_IN', 'stepId': 's1', 'durationMs': 600},
        ],
        'interactions': ['TAP_TO_EXPLORE'],
        'initialState': {},
        'steps': [
          {'id': 's1', 'title': 'Mở', 'durationMs': 800},
          {
            'id': 's2',
            'title': 'Đi',
            'durationMs': 800,
            'targetState': {'routeProgress': {'r': 1}},
          },
        ],
      });
      final frame = ValueNotifier(
        CinematicFrame(camera: mapManifest.cinematic.cameraInitial),
      );
      addTearDown(frame.dispose);

      await tester.pumpWidget(_wrap(mapManifest, frame));
      await tester.pump();
      await tester.ensureVisible(find.text('PHÁT').first);
      await tester.tap(find.text('PHÁT').first);
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
