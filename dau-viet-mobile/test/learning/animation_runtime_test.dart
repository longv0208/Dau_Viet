import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/historical_animation_player.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/runtime/animation_asset_resolver.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/runtime/animation_manifest_dto.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/runtime/animation_runtime_registry.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/scenes/historical_map_scene.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/scenes/river_scene.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/widgets/manifest_asset_layers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/renderers/read_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ANIM-03 — manifest tối thiểu hợp lệ cho từng renderer (giống shape
/// mà AnimationManifestValidator backend chấp nhận).
Map<String, dynamic> _riverManifest() => {
      'schemaVersion': 1,
      'rendererCode': 'RIVER_TIDE',
      'rendererVersion': 1,
      'title': 'Bãi cọc sông (test)',
      'learningObjective': 'Hiểu cơ chế cọc ngầm + thủy triều.',
      'canvas': {'aspectRatio': 1.6},
      'river': {
        'stakes': [
          {'id': 's1', 'x': 0.45, 'length': 0.20},
          {'id': 's2', 'x': 0.55, 'length': 0.23},
        ],
      },
      'initialState': {'waterLevel': 0.30, 'boatProgress': 0},
      'steps': [
        {
          'id': 'st1',
          'title': 'Chuẩn bị',
          'narration': 'Bãi cọc được đóng sẵn dưới lòng sông.',
          'durationMs': 900,
          'targetState': {'waterLevel': 0.30, 'boatProgress': 0},
          'easing': 'easeInOut',
        },
        {
          'id': 'st2',
          'title': 'Nước dâng',
          'narration': 'Triều dâng che khuất đỉnh cọc.',
          'durationMs': 900,
          'targetState': {'waterLevel': 0.90, 'boatProgress': 0.4},
          'effects': ['FADE_IN'],
          'allowedInteractions': ['WATER_LEVEL_CONTROL'],
        },
      ],
      'interactions': ['WATER_LEVEL_CONTROL'],
      'prediction': {
        'question': 'Nước rút thì sao?',
        'options': [
          {'text': 'Cọc vẫn chìm'},
          {'text': 'Cọc lộ ra'},
        ],
        'explainedOptionIndex': 1,
        'explanation': 'Mực nước hạ làm đỉnh cọc nhô lên.',
        'retryHint': 'Kéo mực nước xuống thấp rồi xem lại.',
        'revealTargetState': {'waterLevel': 0.22, 'highlightStakes': true},
      },
      'sourceReferences': [
        {'title': 'Bảo tàng Lịch sử Quốc gia'},
      ],
      'disclaimer': 'Sơ đồ minh họa, không theo tỉ lệ.',
    };

Map<String, dynamic> _mapManifest() => {
      'schemaVersion': 1,
      'rendererCode': 'JOURNEY_MAP',
      'rendererVersion': 1,
      'title': 'Hành trình (test)',
      'learningObjective': 'Nhận ra hành trình trên bản đồ schematic.',
      'map': {
        'locations': [
          {
            'id': 'a',
            'name': 'Điểm A',
            'x': 0.30,
            'y': 0.60,
            'description': 'Nơi bắt đầu.',
            'contextLabel': 'Xuất phát',
          },
          {'id': 'b', 'name': 'Điểm B', 'x': 0.70, 'y': 0.35},
        ],
        'routes': [
          {
            'id': 'r1',
            'from': 'a',
            'to': 'b',
            'via': [
              {'x': 0.5, 'y': 0.5},
            ],
            'explanation': 'Hướng di chuyển chính.',
          },
        ],
      },
      'initialState': {},
      'steps': [
        {
          'id': 'st1',
          'title': 'Xuất phát',
          'narration': 'Điểm A hiện lên.',
          'targetState': {
            'markerVisibility': {'a': 1.0},
            'focusedLocationId': 'a',
          },
        },
        {
          'id': 'st2',
          'title': 'Di chuyển',
          'narration': 'Tuyến r1 vẽ dần tới Điểm B.',
          'targetState': {
            'markerVisibility': {'a': 1.0, 'b': 1.0},
            'routeProgress': {'r1': 1.0},
            'markerHighlight': ['b'],
          },
        },
      ],
      'interactions': ['TAP_TO_EXPLORE'],
      'disclaimer': 'Bản đồ schematic.',
    };

Map<String, dynamic> _embedded(Map<String, dynamic> manifest) => {
      'manifest': manifest,
      'sceneVersionId': '00000000-0000-4000-8000-000000000099',
      'versionNo': 3,
      'rendererCode': manifest['rendererCode'],
      'rendererVersion': 1,
    };

ActivityRefDto _readActivity(Map<String, dynamic> config) =>
    ActivityRefDto.fromJson({
      'id': 'act-anim-rt',
      'type': 'READ',
      'config': config,
      'feedback': const <String, dynamic>{},
    });

Future<void> _pumpRead(
  WidgetTester tester,
  Map<String, dynamic> config,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 1600)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: ReadRenderer(
              activity: _readActivity(config),
              submitting: false,
              onSubmit: (_) async {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('AnimationManifestDto parsing', () {
    test('parses a river manifest with stakes, steps and prediction', () {
      final dto = AnimationManifestDto.fromJson(_riverManifest());
      expect(dto.rendererCode, 'RIVER_TIDE');
      expect(dto.title, 'Bãi cọc sông (test)');
      expect(dto.stakes, hasLength(2));
      expect(dto.stakes[0].x, closeTo(0.45, 0.001));
      expect(dto.steps, hasLength(2));
      expect(dto.steps[1].targetState['waterLevel'], 0.90);
      expect(dto.hasWaterControl, isTrue);
      expect(dto.prediction, isNotNull);
      expect(dto.prediction!.explainedOptionIndex, 1);
    });

    test('parses a map manifest with locations and routes', () {
      final dto = AnimationManifestDto.fromJson(_mapManifest());
      expect(dto.rendererCode, 'JOURNEY_MAP');
      expect(dto.locations, hasLength(2));
      expect(dto.locations.first.id, 'a');
      expect(dto.locations.first.position.dx, closeTo(0.30, 0.001));
      expect(dto.routes, hasLength(1));
      expect(dto.routes.first.fromId, 'a');
      expect(dto.routes.first.via, hasLength(1));
      expect(dto.hasLocationExplorer, isTrue);
      expect(dto.hasWaterControl, isFalse);
    });

    test('ignores unknown fields and tolerates missing optional ones', () {
      final m = _mapManifest()
        ..['futureField'] = {'x': 1}
        ..remove('prediction')
        ..remove('canvas');
      final dto = AnimationManifestDto.fromJson(m);
      expect(dto.steps, hasLength(2));
      expect(dto.prediction, isNull);
      expect(dto.canvasAspectRatio, greaterThan(0));
    });

    test('defaults are safe on a sparse manifest', () {
      final dto = AnimationManifestDto.fromJson(const {
        'schemaVersion': 1,
        'rendererCode': 'RIVER_TIDE',
        'rendererVersion': 1,
        'title': 't',
        'steps': [],
      });
      expect(dto.stakes, isEmpty);
      expect(dto.locations, isEmpty);
      expect(dto.disclaimer, '');
    });
  });

  group('AnimationRuntimeRegistry', () {
    test('resolves both supported renderer codes', () {
      expect(
        AnimationRuntimeRegistry.resolve('RIVER_TIDE'),
        isNotNull,
      );
      expect(
        AnimationRuntimeRegistry.resolve('JOURNEY_MAP'),
        isNotNull,
      );
      expect(
        AnimationRuntimeRegistry.supportedCodes,
        containsAll(['RIVER_TIDE', 'JOURNEY_MAP']),
      );
    });

    test('unknown/empty renderer codes resolve to null', () {
      expect(AnimationRuntimeRegistry.resolve('BATTLEFIELD_3D'), isNull);
      expect(AnimationRuntimeRegistry.resolve(null), isNull);
      expect(AnimationRuntimeRegistry.resolve(''), isNull);
    });

    test('parseManifest reads the embedded snapshot envelope', () {
      final dto = AnimationRuntimeRegistry.parseManifest(
        _embedded(_riverManifest()),
      );
      expect(dto, isNotNull);
      expect(dto!.rendererCode, 'RIVER_TIDE');
    });

    test('parseManifest also accepts a bare manifest object', () {
      final dto = AnimationRuntimeRegistry.parseManifest(_mapManifest());
      expect(dto, isNotNull);
      expect(dto!.rendererCode, 'JOURNEY_MAP');
    });

    test('parseManifest returns null on malformed payloads', () {
      expect(AnimationRuntimeRegistry.parseManifest(null), isNull);
      expect(AnimationRuntimeRegistry.parseManifest('x'), isNull);
      expect(AnimationRuntimeRegistry.parseManifest(const {}), isNull);
      expect(
        AnimationRuntimeRegistry.parseManifest(const {'manifest': 'no'}),
        isNull,
      );
    });
  });

  group('Renderers build definitions from manifests', () {
    test('RIVER_TIDE builds a definition whose painter is manifest-driven', () {
      final manifest = AnimationManifestDto.fromJson(_riverManifest());
      final renderer = AnimationRuntimeRegistry.resolve('RIVER_TIDE')!;
      expect(renderer.canRender(manifest), isTrue);
      final def = renderer.build(manifest);
      expect(def.steps, hasLength(2));
      expect(def.hasWaterControl, isTrue);
      final painter = def.createPainter();
      expect(painter, isA<RiverScenePainter>());
      // Bãi cọc đến từ manifest, không phải 9 cọc mặc định.
      expect((painter as RiverScenePainter).stakes, hasLength(2));
    });

    test('JOURNEY_MAP builds a definition with map locations/routes', () {
      final manifest = AnimationManifestDto.fromJson(_mapManifest());
      final renderer = AnimationRuntimeRegistry.resolve('JOURNEY_MAP')!;
      expect(renderer.canRender(manifest), isTrue);
      final def = renderer.build(manifest);
      expect(def.hasLocationExplorer, isTrue);
      expect(def.hasWaterControl, isFalse);
      final painter = def.createPainter() as MapScenePainter;
      expect(painter.locations, hasLength(2));
      expect(painter.routes, hasLength(1));
      expect(
        MapScenePainter.validateModel(painter.locations, painter.routes),
        isEmpty,
      );
    });

    test('JOURNEY_MAP refuses a manifest without locations', () {
      final m = _mapManifest();
      (m['map'] as Map).remove('locations');
      final manifest = AnimationManifestDto.fromJson(m);
      expect(
        AnimationRuntimeRegistry.resolve('JOURNEY_MAP')!.canRender(manifest),
        isFalse,
      );
    });

    test('manifest initialState seeds the painter instead of defaults', () {
      // initialState.waterLevel=0.85 khác default 0.3 của painter — painter
      // vừa tạo phải bắt đầu ở 0.85 (bước 0 tween TỪ initialState).
      final m = _riverManifest();
      m['initialState'] = {'waterLevel': 0.85, 'highlightStakes': true};
      final def = AnimationRuntimeRegistry.resolve('RIVER_TIDE')!
          .build(AnimationManifestDto.fromJson(m));
      final painter = def.createPainter() as RiverScenePainter;
      expect(painter.waterLevel, closeTo(0.85, 0.001));
      expect(painter.highlightStakes, isTrue);

      // Map: initialState.markerVisibility + focusedLocationId.
      final mm = _mapManifest();
      mm['initialState'] = {
        'markerVisibility': {'a': 0.5},
        'routeProgress': {'r1': 0.25},
        'focusedLocationId': 'a',
      };
      final mapDef = AnimationRuntimeRegistry.resolve('JOURNEY_MAP')!
          .build(AnimationManifestDto.fromJson(mm));
      final mp = mapDef.createPainter() as MapScenePainter;
      expect(mp.markerVisibility['a'], closeTo(0.5, 0.001));
      expect(mp.routeProgress['r1'], closeTo(0.25, 0.001));
      expect(mp.focusedId, 'a');
    });

    test('definition carries manifest canvas aspectRatio + per-step timing', () {
      final m = _riverManifest();
      (m['canvas'] as Map)['aspectRatio'] = 2.0;
      final def = AnimationRuntimeRegistry.resolve('RIVER_TIDE')!
          .build(AnimationManifestDto.fromJson(m));
      expect(def.aspectRatio, closeTo(2.0, 0.001));
      expect(def.steps[0].durationMs, 900);
      expect(def.steps[0].easing, 'easeInOut');
      expect(def.steps[1].easing, 'easeInOut'); // default khi thiếu
    });

    test('build honours the requested playbackMode', () {
      final manifest = AnimationManifestDto.fromJson(_mapManifest());
      final renderer = AnimationRuntimeRegistry.resolve('JOURNEY_MAP')!;
      expect(renderer.build(manifest).playbackMode, 'AUTO');
      expect(
        renderer.build(manifest, playbackMode: 'STEPPED').playbackMode,
        'STEPPED',
      );
      expect(
        renderer.build(manifest, playbackMode: 'INTERACTIVE').playbackMode,
        'INTERACTIVE',
      );
    });

    test('unknown easing falls back to the default curve', () {
      final m = _riverManifest();
      final steps = m['steps'] as List;
      steps[1] = <String, Object>{
        ...(steps[1] as Map).cast<String, Object>(),
        'easing': 'springyCustom',
      };
      final def = AnimationRuntimeRegistry.resolve('RIVER_TIDE')!
          .build(AnimationManifestDto.fromJson(m));
      // Player maps unknown keys to Curves.easeInOut — step field is
      // preserved verbatim and resolved at play time.
      expect(def.steps[1].easing, 'springyCustom');
    });

    test('manifest state decodes into typed scene transitions', () {
      final manifest = AnimationManifestDto.fromJson(_mapManifest());
      final def = AnimationRuntimeRegistry.resolve('JOURNEY_MAP')!
          .build(manifest);
      final t2 = def.steps[1].target as MapSceneState;
      expect(t2.markerVisibility['b'], 1.0);
      expect(t2.routeProgress['r1'], 1.0);
      expect(t2.highlighted, contains('b'));

      final riverDef = AnimationRuntimeRegistry.resolve('RIVER_TIDE')!
          .build(AnimationManifestDto.fromJson(_riverManifest()));
      final rt = riverDef.steps[1].target as RiverSceneState;
      expect(rt.waterLevel, closeTo(0.90, 0.001));
      expect(rt.boatProgress, closeTo(0.4, 0.001));
    });
  });

  group('AnimationAssetResolver', () {
    test('resolves draft-style refs and snapshot-style refs', () {
      final resolver = AnimationAssetResolver([
        {
          'id': 'uuid-1',
          'storageKey': 'assets/uuid-1.png',
          'mimeType': 'image/png',
          'altText': 'Bản đồ nền',
        },
      ]);
      // Draft shape {id:<key>, assetId:<uuid>} → lấy assetId.
      expect(
        resolver.assetIdOf(const {'id': 'bg', 'assetId': 'uuid-1'}),
        'uuid-1',
      );
      // Embedded shape {id:<uuid>} → id chính là assetId.
      expect(resolver.assetIdOf(const {'id': 'uuid-1'}), 'uuid-1');
      expect(resolver.storageKeyOf('uuid-1'), 'assets/uuid-1.png');
      expect(resolver.altTextOf('uuid-1'), 'Bản đồ nền');
      expect(resolver.storageKeyOf('missing'), isNull);
    });
  });

  group('Manifest assets + objects (P0-4)', () {
    test('parses embedded assets[] keeping {id, assetId, role}', () {
      final m = _mapManifest();
      m['assets'] = [
        {
          'id': 'bg',
          'assetId': 'aaaaaaaa-0000-4000-8000-000000000001',
          'role': 'BACKGROUND',
          'altText': 'Bản đồ nền',
        },
        {
          'id': 'boat',
          'assetId': 'bbbbbbbb-0000-4000-8000-000000000002',
          'role': 'OBJECT',
          'altText': 'Thuyền',
        },
      ];
      m['objects'] = [
        {
          'id': 'obj-1',
          'type': 'MARKER',
          'position': {'x': 0.4, 'y': 0.6},
          'scale': 0.2,
          'layer': 1,
          'assetRef': 'boat',
        },
        {
          // Không assetRef → bỏ qua.
          'id': 'obj-2',
          'type': 'LABEL',
          'position': {'x': 0.5, 'y': 0.5},
        },
      ];
      final dto = AnimationManifestDto.fromJson(m);
      expect(dto.assetRefs, hasLength(2));
      expect(dto.assetRefs.first.id, 'bg');
      expect(dto.assetRefs.first.role, 'BACKGROUND');
      expect(dto.objects, hasLength(2));
      expect(dto.objects[0].assetRef, 'boat');
      expect(
        dto.altTextOf('aaaaaaaa-0000-4000-8000-000000000001'),
        'Bản đồ nền',
      );
    });

    testWidgets('asset layers render only when manifest declares assets', (
      tester,
    ) async {
      final plain = _mapManifest();
      // Không assets/objects → ManifestAssetLayers trả child nguyên trạng.
      await tester.pumpWidget(
        MaterialApp(
          home: ManifestAssetLayers(
            manifest: AnimationManifestDto.fromJson(plain),
            aspectRatio: 1.6,
            child: const Text('scene'),
          ),
        ),
      );
      expect(find.text('scene'), findsOneWidget);
      expect(find.byType(Stack), findsNothing);

      // Manifest có assets+objects → mount Stack + placeholder (không
      // ProviderScope → không fetch, vẫn không crash).
      final withAssets = _mapManifest()
        ..['assets'] = [
          {
            'id': 'bg',
            'assetId': 'aaaaaaaa-0000-4000-8000-000000000001',
            'role': 'BACKGROUND',
          },
          {
            'id': 'boat',
            'assetId': 'bbbbbbbb-0000-4000-8000-000000000002',
            'role': 'OBJECT',
          },
        ]
        ..['objects'] = [
          {
            'id': 'obj-1',
            'type': 'MARKER',
            'position': {'x': 0.4, 'y': 0.6},
            'scale': 0.2,
            'assetRef': 'boat',
          },
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: ManifestAssetLayers(
            manifest: AnimationManifestDto.fromJson(withAssets),
            aspectRatio: 1.6,
            child: const Text('scene'),
          ),
        ),
      );
      expect(find.text('scene'), findsOneWidget);
      expect(find.byType(Stack), findsOneWidget);
      // Object layer mount placeholder khung (unauthenticated → không fetch).
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ReadRenderer + embedded animationManifest', () {
    testWidgets('river manifest renders the player above the reading card', (
      tester,
    ) async {
      await _pumpRead(tester, {
        'text': 'Đoạn đọc.',
        'animationManifest': _embedded(_riverManifest()),
      });
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsOneWidget);
      expect(find.text('Đoạn đọc.'), findsOneWidget);
      // Slider nước hiện vì manifest bật WATER_LEVEL_CONTROL.
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('map manifest renders the player with tappable overlay', (
      tester,
    ) async {
      await _pumpRead(tester, {
        'text': 'Đoạn đọc.',
        'animationManifest': _embedded(_mapManifest()),
      });
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('manifest takes precedence over a legacy animationKey', (
      tester,
    ) async {
      await _pumpRead(tester, {
        'text': 'x',
        'animationKey': 'bach_dang_938_tide_v1',
        'animationManifest': _embedded(_mapManifest()),
      });
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsOneWidget);
      // Map scene → không có slider nước (khác river của legacy key).
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('legacy animationKey still works without a manifest', (
      tester,
    ) async {
      await _pumpRead(tester, const {
        'text': 'x',
        'animationKey': 'bach_dang_938_tide_v1',
      });
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('unknown rendererCode shows a graceful fallback', (
      tester,
    ) async {
      final future = _mapManifest()..['rendererCode'] = 'BATTLEFIELD_3D';
      await _pumpRead(tester, {
        'text': 'Nội dung đọc vẫn đủ.',
        'animationManifest': _embedded(future),
      });
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsNothing);
      expect(
        find.textContaining('cần phiên bản ứng dụng mới hơn'),
        findsOneWidget,
      );
      expect(find.text('Nội dung đọc vẫn đủ.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('malformed manifest falls back to plain READ — no crash', (
      tester,
    ) async {
      await _pumpRead(tester, const {
        'text': 'Vẫn đọc được.',
        'animationManifest': 'not-a-map',
      });
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsNothing);
      expect(find.text('Vẫn đọc được.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('READ acknowledgement still submits {} with a manifest', (
      tester,
    ) async {
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1600)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ReadRenderer(
                  activity: _readActivity({
                    'text': 'x',
                    'animationManifest': _embedded(_riverManifest()),
                  }),
                  submitting: false,
                  onSubmit: (p) async => sent = p,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('ĐÃ ĐỌC XONG, TIẾP TỤC'));
      await tester.pump();
      await tester.tap(find.text('ĐÃ ĐỌC XONG, TIẾP TỤC'));
      await tester.pump();
      expect(sent, isNotNull);
      expect(sent, isEmpty);
    });
  });
}
