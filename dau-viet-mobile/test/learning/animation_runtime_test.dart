import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/historical_animation_player.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/runtime/animation_asset_resolver.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/runtime/animation_manifest_dto.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/runtime/animation_runtime_registry.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/scenes/historical_map_scene.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/scenes/river_scene.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/widgets/manifest_asset_layers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/animations/widgets/map_marker_overlay.dart';
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

Future<void> _pumpRead(WidgetTester tester, Map<String, dynamic> config) {
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
      expect(AnimationRuntimeRegistry.resolve('RIVER_TIDE'), isNotNull);
      expect(AnimationRuntimeRegistry.resolve('JOURNEY_MAP'), isNotNull);
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

    /* ---------- FIX-P1 — parseManifestDetailed (typed 3-nhánh) -------- */

    test('parseManifestDetailed: absent chỉ khi payload null', () {
      final res = AnimationRuntimeRegistry.parseManifestDetailed(null);
      expect(res.present, isFalse);
      expect(res.dto, isNull);
      // Mọi payload KHÁC null (kể cả shape sai) đều là "có manifest" —
      // không được rơi về legacy animationKey.
      for (final bad in [
        'not-a-map',
        42,
        const ['a'],
        const {},
        const {'manifest': 'no'},
        const {'manifest': 7},
      ]) {
        expect(
          AnimationRuntimeRegistry.parseManifestDetailed(bad).present,
          isTrue,
          reason: 'payload $bad phải được coi là manifest present-invalid',
        );
      }
    });

    test('parseManifestDetailed: missing/empty rendererCode → invalid', () {
      // Map hợp lệ JSON nhưng không rendererCode → DTO parse được nhưng
      // rendererCode rỗng → invalid (không mount được renderer nào).
      final noCode = AnimationRuntimeRegistry.parseManifestDetailed(
        _embedded(_riverManifest()..remove('rendererCode')),
      );
      expect(noCode.present, isTrue);
      expect(noCode.dto, isNull);
      final emptyCode = AnimationRuntimeRegistry.parseManifestDetailed(
        _embedded(_riverManifest()..['rendererCode'] = ''),
      );
      expect(emptyCode.present, isTrue);
      expect(emptyCode.dto, isNull);
    });

    test('parseManifestDetailed: envelope thiếu key manifest → bare map', () {
      // Envelope không có 'manifest' → parse như bare manifest (compat).
      // Bare map không rendererCode → invalid.
      final bare = AnimationRuntimeRegistry.parseManifestDetailed(const {
        'title': 'x',
      });
      expect(bare.present, isTrue);
      expect(bare.dto, isNull);
      // Bare manifest đầy đủ → ok.
      final ok = AnimationRuntimeRegistry.parseManifestDetailed(
        _riverManifest(),
      );
      expect(ok.present, isTrue);
      expect(ok.dto, isNotNull);
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
      final def = AnimationRuntimeRegistry.resolve(
        'RIVER_TIDE',
      )!.build(AnimationManifestDto.fromJson(m));
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
      final mapDef = AnimationRuntimeRegistry.resolve(
        'JOURNEY_MAP',
      )!.build(AnimationManifestDto.fromJson(mm));
      final mp = mapDef.createPainter() as MapScenePainter;
      expect(mp.markerVisibility['a'], closeTo(0.5, 0.001));
      expect(mp.routeProgress['r1'], closeTo(0.25, 0.001));
      expect(mp.focusedId, 'a');
    });

    test(
      'definition carries manifest canvas aspectRatio + per-step timing',
      () {
        final m = _riverManifest();
        (m['canvas'] as Map)['aspectRatio'] = 2.0;
        final def = AnimationRuntimeRegistry.resolve(
          'RIVER_TIDE',
        )!.build(AnimationManifestDto.fromJson(m));
        expect(def.aspectRatio, closeTo(2.0, 0.001));
        expect(def.steps[0].durationMs, 900);
        expect(def.steps[0].easing, 'easeInOut');
        expect(def.steps[1].easing, 'easeInOut'); // default khi thiếu
      },
    );

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
      final def = AnimationRuntimeRegistry.resolve(
        'RIVER_TIDE',
      )!.build(AnimationManifestDto.fromJson(m));
      // Player maps unknown keys to Curves.easeInOut — step field is
      // preserved verbatim and resolved at play time.
      expect(def.steps[1].easing, 'springyCustom');
    });

    test('manifest state decodes into typed scene transitions', () {
      final manifest = AnimationManifestDto.fromJson(_mapManifest());
      final def = AnimationRuntimeRegistry.resolve(
        'JOURNEY_MAP',
      )!.build(manifest);
      final t2 = def.steps[1].target as MapSceneState;
      expect(t2.markerVisibility['b'], 1.0);
      expect(t2.routeProgress['r1'], 1.0);
      expect(t2.highlighted, contains('b'));

      final riverDef = AnimationRuntimeRegistry.resolve(
        'RIVER_TIDE',
      )!.build(AnimationManifestDto.fromJson(_riverManifest()));
      final rt = riverDef.steps[1].target as RiverSceneState;
      expect(rt.waterLevel, closeTo(0.90, 0.001));
      expect(rt.boatProgress, closeTo(0.4, 0.001));
    });
  });

  group('FIX-06 — version gating (schemaVersion / rendererVersion)', () {
    test('schemaVersion=2 manifest vẫn render được (v2 keys hiểu)', () {
      final m = _riverManifest()..['schemaVersion'] = 2;
      final manifest = AnimationManifestDto.fromJson(m);
      expect(manifest.schemaVersion, 2);
      expect(
        AnimationRuntimeRegistry.resolve('RIVER_TIDE')!.canRender(manifest),
        isTrue,
      );
      final mm = _mapManifest()..['schemaVersion'] = 2;
      expect(
        AnimationRuntimeRegistry.resolve(
          'JOURNEY_MAP',
        )!.canRender(AnimationManifestDto.fromJson(mm)),
        isTrue,
      );
    });

    test(
      'schemaVersion tương lai (3) → canRender false, không silently drop',
      () {
        final m = _riverManifest()..['schemaVersion'] = 3;
        final manifest = AnimationManifestDto.fromJson(m);
        // DTO vẫn parse được (bỏ qua field lạ) nhưng renderer từ chối.
        expect(manifest.schemaVersion, 3);
        expect(
          AnimationRuntimeRegistry.resolve('RIVER_TIDE')!.canRender(manifest),
          isFalse,
        );
        final mm = _mapManifest()..['schemaVersion'] = 3;
        expect(
          AnimationRuntimeRegistry.resolve(
            'JOURNEY_MAP',
          )!.canRender(AnimationManifestDto.fromJson(mm)),
          isFalse,
        );
      },
    );

    test('rendererVersion=2 > supported → canRender false', () {
      final m = _riverManifest()..['rendererVersion'] = 2;
      expect(
        AnimationRuntimeRegistry.resolve(
          'RIVER_TIDE',
        )!.canRender(AnimationManifestDto.fromJson(m)),
        isFalse,
      );
      final mm = _mapManifest()..['rendererVersion'] = 2;
      expect(
        AnimationRuntimeRegistry.resolve(
          'JOURNEY_MAP',
        )!.canRender(AnimationManifestDto.fromJson(mm)),
        isFalse,
      );
    });

    testWidgets('schemaVersion=3 → explicit unsupported notice, không crash', (
      tester,
    ) async {
      final future = _riverManifest()..['schemaVersion'] = 3;
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
      // Bước 0 không khai báo allowedInteractions → vẫn definition-level
      // (WATER_LEVEL_CONTROL scene-global) → slider hiện.
      expect(find.byType(Slider), findsOneWidget);
    });

    /* ---------- P0 — prediction checkpoint gating (manifest-driven) ------ */

    test(
      'manifest binds prediction.stepIndex via step allowedInteractions',
      () {
        // Bước 2 khai báo PREDICTION → checkpoint tại đó.
        final bound = _riverManifest();
        (bound['steps'] as List)[1] = <String, Object>{
          ...((bound['steps'] as List)[1] as Map).cast<String, Object>(),
          'allowedInteractions': ['PREDICTION', 'WATER_LEVEL_CONTROL'],
        };
        final def = AnimationRuntimeRegistry.resolve(
          'RIVER_TIDE',
        )!.build(AnimationManifestDto.fromJson(bound));
        expect(def.prediction!.stepIndex, 1);

        // Không bước nào khai báo → fallback giữa scene (không để
        // prediction "không bao giờ hiện" trên manifest thiếu binding).
        final unbound = _riverManifest(); // step 1 chỉ WATER_LEVEL_CONTROL
        final defUnbound = AnimationRuntimeRegistry.resolve(
          'RIVER_TIDE',
        )!.build(AnimationManifestDto.fromJson(unbound));
        expect(defUnbound.prediction!.stepIndex, isNotNull);
      },
    );

    testWidgets('manifest prediction shows only at its checkpoint step', (
      tester,
    ) async {
      // Gắn PREDICTION vào bước 2 (index 1) — khối chỉ được hiện ở đó.
      final m = _riverManifest();
      (m['steps'] as List)[1] = <String, Object>{
        ...((m['steps'] as List)[1] as Map).cast<String, Object>(),
        'allowedInteractions': ['PREDICTION', 'WATER_LEVEL_CONTROL'],
      };
      await _pumpRead(tester, {
        'text': 'Đoạn đọc.',
        'animationManifest': _embedded(m),
      });
      await tester.pump();
      // Bước 1: không được hiện khối dự đoán (scroll để widget dựng).
      await tester.ensureVisible(find.text('Đoạn đọc.'));
      await tester.pump();
      expect(find.text('DỰ ĐOÁN KHÁM PHÁ'), findsNothing);
      // Sang bước checkpoint → khối xuất hiện.
      await tester.ensureVisible(find.bySemanticsLabel('Bước tiếp').first);
      await tester.tap(find.bySemanticsLabel('Bước tiếp').first);
      await tester.pump();
      expect(find.text('DỰ ĐOÁN KHÁM PHÁ'), findsOneWidget);
      // Quay lại bước 1 → khối biến mất.
      await tester.ensureVisible(find.bySemanticsLabel('Bước trước').first);
      await tester.tap(find.bySemanticsLabel('Bước trước').first);
      await tester.pump();
      expect(find.text('DỰ ĐOÁN KHÁM PHÁ'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('manifest AUTO does not pass an unresolved prediction', (
      tester,
    ) async {
      // Prediction bound ở bước 2 (cuối) → AUTO dừng ở đó, không được
      // tự kết thúc khi learner chưa reveal.
      final m = _riverManifest();
      (m['steps'] as List)[1] = <String, Object>{
        ...((m['steps'] as List)[1] as Map).cast<String, Object>(),
        'allowedInteractions': ['PREDICTION', 'WATER_LEVEL_CONTROL'],
      };
      await _pumpRead(tester, {
        'text': 'Đoạn đọc.',
        'animationManifest': _embedded(m),
      });
      await tester.pump();
      await tester.ensureVisible(find.text('PHÁT'));
      await tester.tap(find.text('PHÁT'));
      await tester.pump();
      // Chờ qua mọi timer có thể — vẫn không được vượt checkpoint.
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(find.textContaining('Bước 2/2'), findsOneWidget);
      expect(find.text('PHÁT'), findsOneWidget); // đã dừng chờ learner
      expect(find.text('DỰ ĐOÁN KHÁM PHÁ'), findsOneWidget);
      // Reveal → bấm PHÁT → hết bước cuối, tự dừng (không auto-reveal).
      await tester.ensureVisible(find.textContaining('Cọc lộ ra'));
      await tester.tap(find.textContaining('Cọc lộ ra'));
      await tester.pump();
      await tester.ensureVisible(find.text('XEM KẾT QUẢ VÀ GIẢI THÍCH'));
      await tester.tap(find.text('XEM KẾT QUẢ VÀ GIẢI THÍCH'));
      await tester.pump();
      await tester.ensureVisible(find.text('PHÁT'));
      await tester.tap(find.text('PHÁT'));
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(find.text('PHÁT'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
        // Kèm legacy key để chứng minh manifest hỏng KHÔNG rơi về legacy.
        'animationKey': 'bach_dang_938_tide_v1',
      });
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsNothing);
      expect(find.text('Vẫn đọc được.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    /* ---------- FIX-P1 — 3-nhánh fallback trong READ ------------------ */

    testWidgets('missing rendererCode → notice, giữ READ, không crash', (
      tester,
    ) async {
      final broken = _riverManifest()..remove('rendererCode');
      await _pumpRead(tester, {
        'text': 'Nội dung đọc vẫn đủ.',
        'animationManifest': _embedded(broken),
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

    testWidgets('unsupported rendererVersion → notice, không silent drop', (
      tester,
    ) async {
      final future = _riverManifest()..['rendererVersion'] = 2;
      await _pumpRead(tester, {
        'text': 'Đọc được.',
        'animationManifest': _embedded(future),
      });
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsNothing);
      expect(
        find.textContaining('cần phiên bản ứng dụng mới hơn'),
        findsOneWidget,
      );
      expect(find.text('Đọc được.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('map thiếu locations → canRender false → notice', (
      tester,
    ) async {
      final broken = _mapManifest();
      (broken['map'] as Map).remove('locations');
      await _pumpRead(tester, {
        'text': 'Bản đồ thiếu điểm.',
        'animationManifest': _embedded(broken),
      });
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsNothing);
      expect(
        find.textContaining('cần phiên bản ứng dụng mới hơn'),
        findsOneWidget,
      );
      expect(find.text('Bản đồ thiếu điểm.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('manifest hỏng + legacy key → KHÔNG mount animation khác', (
      tester,
    ) async {
      // Trường hợp nguy hiểm nhất: manifest invalid NHƯNG config cũng có
      // animationKey hợp lệ. Đúng hành vi = notice (manifest là nguồn
      // truth của snapshot), KHÔNG mount river legacy sai ngữ cảnh.
      final broken = _mapManifest()..['schemaVersion'] = 3;
      await _pumpRead(tester, {
        'text': 'x',
        'animationKey': 'bach_dang_938_tide_v1',
        'animationManifest': _embedded(broken),
      });
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsNothing);
      // Không slider nước của legacy river scene.
      expect(find.byType(Slider), findsNothing);
      expect(
        find.textContaining('cần phiên bản ứng dụng mới hơn'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('invalid manifest không tự submit / không auto-complete', (
      tester,
    ) async {
      var submitted = false;
      final broken = _riverManifest()..remove('rendererCode');
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1600)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ReadRenderer(
                  activity: _readActivity({
                    'text': 'x',
                    'animationManifest': _embedded(broken),
                  }),
                  submitting: false,
                  onSubmit: (_) async => submitted = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      // Không có player → không auto-play → onSubmit không được gọi.
      expect(submitted, isFalse);
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

    /* ---------- FIX-02 — step-level interaction whitelist (v2) -------- */

    testWidgets('v2 river manifest: slider only on whitelisted steps', (
      tester,
    ) async {
      // V17 shape: slider chỉ trên bước khai báo WATER_LEVEL_CONTROL —
      // bước rỗng (allowedInteractions: []) KHÔNG có slider, dù manifest
      // interactions[] khai báo scene-global. manifestV2 semantics.
      final m = _riverManifest()..['schemaVersion'] = 2;
      (m['steps'] as List)[0] = <String, Object>{
        ...((m['steps'] as List)[0] as Map).cast<String, Object>(),
        'allowedInteractions': <String>[], // st1: whitelist rỗng
      };
      await _pumpRead(tester, {
        'text': 'Đoạn đọc.',
        'animationManifest': _embedded(m),
      });
      await tester.pump();
      expect(find.byType(HistoricalAnimationPlayer), findsOneWidget);
      // Bước 1 (rỗng) → KHÔNG slider.
      await tester.ensureVisible(find.text('Đoạn đọc.'));
      await tester.pump();
      expect(find.byType(Slider), findsNothing);
      // Sang bước 2 (WATER_LEVEL_CONTROL) → slider hiện.
      await tester.ensureVisible(find.bySemanticsLabel('Bước tiếp').first);
      await tester.tap(find.bySemanticsLabel('Bước tiếp').first);
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('v1 manifest keeps legacy semantics (empty = allowed)', (
      tester,
    ) async {
      // schemaVersion=1 + step 0 không khai báo allowedInteractions →
      // definition-level WATER_LEVEL_CONTROL áp mọi bước (không
      // regression scene cũ trước khi whitelist tồn tại).
      await _pumpRead(tester, {
        'text': 'Đoạn đọc.',
        'animationManifest': _embedded(_riverManifest()),
      });
      await tester.pump();
      await tester.ensureVisible(find.text('Đoạn đọc.'));
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'v2 map manifest: markers tappable only on TAP_TO_EXPLORE steps',
      (tester) async {
        // TAP_TO_EXPLORE chỉ ở bước 2 — bước 1 rỗng: không overlay chạm,
        // không LocationInfoPanel; bước 2: tap marker được (parity admin).
        final m = _mapManifest()..['schemaVersion'] = 2;
        (m['steps'] as List)[0] = <String, Object>{
          ...((m['steps'] as List)[0] as Map).cast<String, Object>(),
          'allowedInteractions': <String>[],
        };
        (m['steps'] as List)[1] = <String, Object>{
          ...((m['steps'] as List)[1] as Map).cast<String, Object>(),
          'allowedInteractions': ['TAP_TO_EXPLORE'],
        };
        await _pumpRead(tester, {
          'text': 'Đoạn đọc.',
          'animationManifest': _embedded(m),
        });
        await tester.pump();
        expect(find.byType(HistoricalAnimationPlayer), findsOneWidget);
        // Bước 1: marker 'a' hiện (targetState) nhưng không tấp được —
        // không MapMarkerOverlay nào được mount.
        expect(find.byType(MapMarkerOverlay), findsNothing);
        // Sang bước 2 (TAP_TO_EXPLORE): overlay mount trên marker đang hiện.
        await tester.ensureVisible(find.bySemanticsLabel('Bước tiếp').first);
        await tester.tap(find.bySemanticsLabel('Bước tiếp').first);
        await tester.pump();
        expect(find.byType(MapMarkerOverlay), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'legacy animationKey definitions stay interactive on all steps',
      (tester) async {
        // Scene v1 hardcode (bach_dang_938_tide_v1): manifestV2=false →
        // slider hiện ở mọi bước (definition-level hasWaterControl) — không
        // làm mất tương tác legacy.
        await _pumpRead(tester, const {
          'text': 'x',
          'animationKey': 'bach_dang_938_tide_v1',
        });
        await tester.pump();
        await tester.ensureVisible(find.text('x'));
        await tester.pump();
        expect(find.byType(Slider), findsOneWidget);
        // Bước 0 không whitelist gì cả → slider vẫn hiện (legacy semantics).
        expect(tester.takeException(), isNull);
      },
    );
  });
}
