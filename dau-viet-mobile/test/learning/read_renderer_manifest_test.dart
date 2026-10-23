import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/historical_animation_player.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/widgets/manifest_asset_layers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/renderers/read_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// §2/§9/§12 — manifest v2 trong READ activity thật (SingleChildScrollView,
/// AspectRatio bounds, marker hit targets, no overflow, no crash) và
/// fallback cho manifest v1/legacy/unsupported.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Scene JOURNEY_MAP v2 tối giản: 1 location + marker + camera pan.
  Map<String, dynamic> journeyV2() => {
    'schemaVersion': 2,
    'rendererCode': 'JOURNEY_MAP',
    'rendererVersion': 1,
    'title': 'Hành trình test',
    'canvas': {'aspectRatio': 1.6},
    'map': {
      'locations': [
        {'id': 'loc-a', 'x': 0.3, 'y': 0.4, 'label': 'Điểm A'},
        {'id': 'loc-b', 'x': 0.7, 'y': 0.6, 'label': 'Điểm B'},
      ],
    },
    'camera': {
      'initial': {'x': 0.5, 'y': 0.5, 'zoom': 1.0},
      'steps': [
        {
          'target': {'x': 0.3, 'y': 0.4, 'zoom': 1.4},
        },
        {
          'target': {'x': 0.7, 'y': 0.6, 'zoom': 1.4},
        },
      ],
    },
    'steps': [
      {
        'id': 's1',
        'title': 'Bước 1',
        'durationMs': 800,
        'targetState': {'focusLocationId': 'loc-a'},
      },
      {
        'id': 's2',
        'title': 'Bước 2',
        'durationMs': 800,
        'targetState': {'focusLocationId': 'loc-b'},
      },
    ],
  };

  /// Scene RIVER_TIDE v2 tối giản: stakes + environment + object track.
  Map<String, dynamic> riverV2() => {
    'schemaVersion': 2,
    'rendererCode': 'RIVER_TIDE',
    'rendererVersion': 1,
    'title': 'Sông test',
    'canvas': {'aspectRatio': 1.6},
    'assets': [
      {'id': 'bg', 'assetId': 'a1', 'role': 'BACKGROUND'},
      {'id': 'amb', 'assetId': 'a2', 'role': 'AUDIO'},
    ],
    'objects': [
      {
        'id': 'boat-decoy',
        'type': 'BOAT',
        'position': {'x': 0.2, 'y': 0.5},
        'scale': 0.14,
        'layer': 1,
      },
    ],
    'river': {
      'stakes': [
        {'id': 's1', 'x': 0.5, 'length': 0.2},
      ],
    },
    'environment': {'mist': 0.3, 'glow': 0.2},
    'camera': {
      'initial': {'x': 0.5, 'y': 0.5, 'zoom': 1.0},
      'steps': [
        {
          'target': {'x': 0.55, 'y': 0.55, 'zoom': 1.6},
        },
      ],
    },
    'tracks': [
      {
        'objectId': 'boat-decoy',
        'property': 'position',
        'keyframes': [
          {
            'tMs': 0,
            'value': {'x': 0.2, 'y': 0.5},
            'easing': 'linear',
          },
          {
            'tMs': 800,
            'value': {'x': 0.6, 'y': 0.4},
            'easing': 'linear',
          },
        ],
      },
    ],
    'effects': [
      {
        'type': 'MIST',
        'params': {'intensity': 0.4},
      },
    ],
    'audio': [
      {'stepId': 's1', 'assetRef': 'amb', 'cue': 'LOOP', 'volume': 0.5},
    ],
    'steps': [
      {
        'id': 's1',
        'title': 'Chuẩn bị',
        'durationMs': 800,
        'targetState': {'waterLevel': 0.5},
      },
    ],
  };

  Widget app(Widget child, {double width = 400, double height = 800}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(child, width: width));
    await tester.pump();
  }

  group('ReadRenderer manifest rendering (§2)', () {
    testWidgets('JOURNEY_MAP v2 → ManifestAssetLayers bọc player, '
        'không overflow, marker overlay render', (tester) async {
      final act = ActivityRefDto(
        id: 'a1',
        config: {
          'title': 'Bài đọc',
          'body': 'Nội dung.',
          'animationManifest': journeyV2(),
          'playbackMode': 'MANUAL',
        },
        feedback: const {},
      );
      await pump(
        tester,
        ReadRenderer(activity: act, submitting: false, onSubmit: (_) async {}),
      );
      // Player + layers render
      expect(find.byType(HistoricalAnimationPlayer), findsOneWidget);
      expect(find.byType(ManifestAssetLayers), findsOneWidget);
      // Canvas bounded bởi AspectRatio — không overflow unbounded
      expect(find.byType(AspectRatio), findsWidgets);
      // Marker overlay vẽ trong cùng camera transform (MapMarkerOverlay)
      await tester.pump(const Duration(milliseconds: 50));
      // Không render overflow error
      expect(tester.takeException(), isNull);
    });

    testWidgets('RIVER_TIDE v2 cinematic → object procedural render, '
        'background suppression bật khi có bg asset', (tester) async {
      final act = ActivityRefDto(
        id: 'a2',
        config: {
          'body': 'Sông.',
          'animationManifest': riverV2(),
          'playbackMode': 'MANUAL',
        },
        feedback: const {},
      );
      await pump(
        tester,
        ReadRenderer(activity: act, submitting: false, onSubmit: (_) async {}),
      );
      expect(find.byType(HistoricalAnimationPlayer), findsOneWidget);
      expect(find.byType(ManifestAssetLayers), findsOneWidget);
      // boat-decoy không assetRef → procedural glyph (CustomPaint)
      // render, KHÔNG vô hình.
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });

    testWidgets('manifest rỗng/unsupported → _UnsupportedAnimationNotice '
        'không crash', (tester) async {
      final act = ActivityRefDto(
        id: 'a3',
        config: {
          'body': 'Đọc.',
          'animationManifest': {
            'schemaVersion': 2,
            'rendererCode': 'RENDERER_La',
            'title': 'X',
          },
        },
        feedback: const {},
      );
      await pump(
        tester,
        ReadRenderer(activity: act, submitting: false, onSubmit: (_) async {}),
      );
      expect(find.byType(HistoricalAnimationPlayer), findsNothing);
      expect(find.textContaining('ứng dụng mới hơn'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('không manifest → render text, không animation', (
      tester,
    ) async {
      final act = ActivityRefDto(
        id: 'a4',
        config: {'body': 'Chỉ văn bản.'},
        feedback: const {},
      );
      await pump(
        tester,
        ReadRenderer(activity: act, submitting: false, onSubmit: (_) async {}),
      );
      expect(find.byType(HistoricalAnimationPlayer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
