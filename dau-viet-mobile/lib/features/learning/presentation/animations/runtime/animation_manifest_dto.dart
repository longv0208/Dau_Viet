import 'package:flutter/material.dart';

import '../scenes/historical_map_scene.dart';
import '../scenes/river_scene.dart';
import '../historical_animation_definition.dart';
import 'cinematic_state.dart';

/// ANIM-03 — DTO bất biến cho animation manifest embedded trong lesson
/// snapshot (`config.animationManifest`). Manifest là DATA whitelist —
/// parser chỉ đọc field đã biết, bỏ qua field lạ (tương thích tương lai).
/// Renderer KHÔNG BAO GIỜ nhận data theo eventId — mọi nội dung scene
/// đến từ manifest.
class AnimationManifestDto {
  final int schemaVersion;
  final String rendererCode;
  final int rendererVersion;
  final String title;
  final String learningObjective;
  final double canvasAspectRatio;
  final List<AnimationStepDto> steps;
  final AnimationPredictionDto? prediction;
  final Set<String> interactions;
  final String disclaimer;
  final List<String> sourceReferences;
  final Duration transitionDuration;

  /// Trạng thái mở đầu của painter (bước 0 tween TỪ đây). Field thiếu
  /// giữ default của painter; key lạ bị bỏ qua ở tầng decode.
  final Map<String, dynamic> initialState;

  /// RIVER_TIDE — bãi cọc khai báo trong manifest (id, x, length).
  final List<RiverStakeDto> stakes;

  /// JOURNEY_MAP — địa điểm + tuyến nối schematic.
  final List<MapLocation> locations;
  final List<MapRoute> routes;

  /// P0-4 — assets[] đã embed trong snapshot publish: `{id, assetId, role}`
  /// + metadata (storageKey/mimeType/altText); `id` là manifest key. Draft
  /// cũng đọc được (`{id, assetId, role}`) — resolver chấp nhận cả hai.
  final List<AnimationAssetRefDto> assetRefs;

  /// P0-4 — objects[] có `assetRef` → assets[].id; position/scale/layer/
  /// shape chuẩn hóa. Chỉ object resolve được role OBJECT mới render.
  final List<AnimationObjectDto> objects;

  /// JOURNEY_MAP — assetId của ảnh nền bản đồ (map.backgroundAssetId).
  final String? backgroundAssetId;

  /// assetId → altText đã embed trong snapshot (a11y/fallback text).
  final Map<String, String> assetAltText;

  // --- Cinematic v2 (tất cả optional — manifest v1 không có key nào) ---

  /// camera {initial, steps[]} — pose viewport per step.
  final CameraTrackDto camera;

  /// tracks[] — keyframe motion per (objectId, property).
  final List<ObjectTrackDto> tracks;

  /// effects[] — typed overlay (WATER_RIPPLE/MIST/GLOW/ROUTE_REVEAL/FADE_*).
  final List<SceneEffectDto> sceneEffects;

  /// audio[] — {stepId, assetRef, cue, volume, fadeMs}.
  final List<AudioCueDto> audioCues;

  /// environment {waterLevel?, mist?, glow?} — RIVER_TIDE ambient.
  final EnvironmentDto environment;

  /// Evaluator dựng sẵn từ manifest — player consume trực tiếp.
  final CinematicEvaluator cinematic;

  const AnimationManifestDto({
    required this.schemaVersion,
    required this.rendererCode,
    required this.rendererVersion,
    required this.title,
    required this.learningObjective,
    required this.canvasAspectRatio,
    required this.steps,
    required this.disclaimer,
    this.prediction,
    this.interactions = const {},
    this.sourceReferences = const [],
    this.transitionDuration = const Duration(milliseconds: 1100),
    this.initialState = const {},
    this.stakes = const [],
    this.locations = const [],
    this.routes = const [],
    this.assetRefs = const [],
    this.objects = const [],
    this.backgroundAssetId,
    this.assetAltText = const {},
    this.camera = const CameraTrackDto(),
    this.tracks = const [],
    this.sceneEffects = const [],
    this.audioCues = const [],
    this.environment = const EnvironmentDto(),
    this.cinematic = const CinematicEvaluator(),
  });

  /// altText của assetId (từ metadata embed trong snapshot); null khi
  /// snapshot chưa pin meta — caller dùng nhãn dự phòng.
  String? altTextOf(String assetId) => assetAltText[assetId];

  /// Instance rỗng — dùng làm fallback khi caller không có manifest
  /// (legacy animationKey). Không asset/object nào → ManifestAssetLayers
  /// trả child nguyên trạng.
  static const empty = AnimationManifestDto(
    schemaVersion: 1,
    rendererCode: '',
    rendererVersion: 1,
    title: '',
    learningObjective: '',
    canvasAspectRatio: 1.6,
    steps: [],
    disclaimer: '',
  );

  /// Parse embedded manifest — field thiếu hoặc sai nhận default an toàn,
  /// không throw (app cũ đọc manifest mới vẫn render phần đọc được).
  factory AnimationManifestDto.fromJson(Map<String, dynamic> json) {
    final map = json['map'];
    final river = json['river'];
    final objects = [
      for (final o in _list(json['objects']))
        if (o is Map) AnimationObjectDto.fromJson(o),
    ];
    final steps = _steps(json['steps']);
    final camera = CameraTrackDto.fromJson(json['camera']);
    final tracks = [
      for (final t in _list(json['tracks']))
        if (t is Map) ObjectTrackDto.fromJson(t),
    ];
    return AnimationManifestDto(
      schemaVersion: _int(json['schemaVersion'], 1),
      rendererCode: json['rendererCode'] as String? ?? '',
      rendererVersion: _int(json['rendererVersion'], 1),
      title: json['title'] as String? ?? '',
      learningObjective: json['learningObjective'] as String? ?? '',
      canvasAspectRatio: _double(
        (json['canvas'] as Map?)?['aspectRatio'],
        16 / 10,
      ),
      steps: steps,
      prediction: _prediction(json['prediction']),
      interactions: {for (final i in _list(json['interactions'])) '$i'},
      disclaimer: json['disclaimer'] as String? ?? '',
      sourceReferences: [
        for (final r in _list(json['sourceReferences']))
          if (r is Map && r['title'] != null) '${r['title']}',
      ],
      transitionDuration: Duration(
        milliseconds: _int(json['transitionDurationMs'], 1100),
      ),
      initialState: json['initialState'] is Map
          ? Map<String, dynamic>.from(json['initialState'] as Map)
          : const {},
      stakes: river is Map
          ? [
              for (final s in _list(river['stakes']))
                if (s is Map) RiverStakeDto.fromJson(s),
            ]
          : const [],
      locations: map is Map
          ? [
              for (final l in _list(map['locations']))
                if (l is Map) _location(l),
            ]
          : const [],
      routes: map is Map
          ? [
              for (final r in _list(map['routes']))
                if (r is Map) _route(r),
            ]
          : const [],
      assetRefs: _assetRefs(json['assets']),
      objects: objects,
      backgroundAssetId: map is Map
          ? map['backgroundAssetId'] as String?
          : null,
      assetAltText: {
        for (final a in _list(json['assets']))
          if (a is Map)
            // Snapshot embed: id = manifest key, assetId = uuid thật;
            // draft cũ: id có thể chính là uuid. Cả hai đều map về
            // assetId fetch được.
            '${a['assetId'] ?? a['id']}': '${a['altText'] ?? ''}',
      }..removeWhere((k, v) => v.isEmpty || k == 'null'),
      camera: camera,
      tracks: tracks,
      sceneEffects: [
        for (final e in _list(json['effects']))
          if (e is Map) SceneEffectDto.fromJson(e),
      ],
      audioCues: [
        for (final a in _list(json['audio']))
          if (a is Map) AudioCueDto.fromJson(a),
      ],
      environment: EnvironmentDto.fromJson(json['environment']),
      cinematic: CinematicEvaluator(
        cameraInitial: camera.initial,
        cameraSteps: camera.steps,
        // §5 — camera.steps[].easing (whitelist) override step.easing
        // khi camera tween — camera pan/zoom độc lập với lerp painter.
        cameraEasings: [
          for (final e in camera.easings)
            e == null ? null : ObjectTrackDto._curve(e),
        ],
        // FIX-05 — camera.steps[].durationMs > 0 → camera tween hoàn
        // thành trong khoảng đó rồi GIỮ POSE cho phần còn lại của step.
        cameraStepDurationsMs: camera.stepDurationsMs,
        // P1 §3 — step.easing per-step: cần để camera-duration window
        // vẫn dùng step.easing (đúng 1 lần) khi không có camera.easing.
        stepEasings: [for (final s in steps) ObjectTrackDto._curve(s.easing)],
        tracks: [
          for (final t in tracks)
            ObjectTrackSpec(
              objectId: t.objectId,
              property: t.property,
              keyframes: t.keyframes,
            ),
        ],
        baseObjects: {
          for (final o in objects)
            o.id: ObjectVisualState(
              position: o.position,
              scale: o.scale,
              rotation: o.rotation,
              opacity: o.opacity,
              visible: o.visible,
            ),
        },
        stepDurationsMs: [
          for (final s in steps) s.durationMs > 0 ? s.durationMs : 4000,
        ],
        stepIds: [for (final s in steps) s.id],
        effects: [
          for (final e in _list(json['effects']))
            if (e is Map)
              SceneEffectSpec(
                type: '${e['type'] ?? ''}',
                stepId: e['stepId'] as String?,
                durationMs: _int(e['durationMs'], 0),
                center: Offset(
                  _double((e['params'] as Map?)?['x'], 0.5),
                  _double((e['params'] as Map?)?['y'], 0.5),
                ),
                intensity: _double(
                  (e['params'] as Map?)?['intensity'],
                  0.5,
                ).clamp(0.0, 1.0),
                objectId: (e['params'] as Map?)?['objectId'] as String?,
              ),
        ],
      ),
    );
  }

  bool get hasWaterControl => interactions.contains('WATER_LEVEL_CONTROL');
  bool get hasLocationExplorer => interactions.contains('TAP_TO_EXPLORE');

  /// P0 §3 — manifest khai báo ảnh nền (map.backgroundAssetId hoặc
  /// assets[] role BACKGROUND). Khi `true` painter skip base opaque
  /// background để ảnh hiển thị (không phá scene v1 không có ảnh).
  bool get hasBackgroundAsset {
    final bg = backgroundAssetId;
    if (bg != null && bg.isNotEmpty) return true;
    return assetRefs.any((a) => a.role == 'BACKGROUND');
  }

  static List<AnimationStepDto> _steps(Object? raw) => [
    for (final s in _list(raw))
      if (s is Map) AnimationStepDto.fromJson(s),
  ];

  static AnimationPredictionDto? _prediction(Object? raw) =>
      raw is Map ? AnimationPredictionDto.fromJson(raw) : null;

  /// assets[] → ref typed. Snapshot embed đã pin `{id: key, assetId,
  /// role}`; bỏ entry thiếu assetId (validator backend đã chặn, đây là
  /// lớp phòng thủ thứ hai cho payload thủ công).
  static List<AnimationAssetRefDto> _assetRefs(Object? raw) => [
    for (final a in _list(raw))
      if (a is Map && a['assetId'] != null)
        AnimationAssetRefDto(
          id: '${a['id'] ?? ''}',
          assetId: '${a['assetId']}',
          role: '${a['role'] ?? 'OBJECT'}',
        ),
  ];

  static MapLocation _location(Map l) => MapLocation(
    id: '${l['id'] ?? ''}',
    name: '${l['name'] ?? ''}',
    position: Offset(_double(l['x'], 0.5), _double(l['y'], 0.5)),
    description: '${l['description'] ?? ''}',
    contextLabel: l['contextLabel'] as String?,
  );

  static MapRoute _route(Map r) => MapRoute(
    id: '${r['id'] ?? ''}',
    fromId: '${r['from'] ?? ''}',
    toId: '${r['to'] ?? ''}',
    via: [
      for (final v in _list(r['via']))
        if (v is Map) Offset(_double(v['x'], 0.5), _double(v['y'], 0.5)),
    ],
    explanation: '${r['explanation'] ?? ''}',
  );
}

/// Một bước narration + target state typed-free (decoder build riêng
/// theo rendererCode — giữ manifest renderer-agnostic ở tầng DTO).
class AnimationStepDto {
  final String id;
  final String title;
  final String narration;
  final String? hint;
  final int durationMs;
  final Map<String, dynamic> targetState;
  final String easing;
  final Set<String> effects;
  final Set<String> allowedInteractions;

  const AnimationStepDto({
    required this.id,
    required this.title,
    required this.narration,
    required this.durationMs,
    required this.targetState,
    this.hint,
    this.easing = 'easeInOut',
    this.effects = const {},
    this.allowedInteractions = const {},
  });

  factory AnimationStepDto.fromJson(Map json) => AnimationStepDto(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    narration: '${json['narration'] ?? ''}',
    hint: json['hint'] as String?,
    durationMs: _int(json['durationMs'], 1100),
    targetState: json['targetState'] is Map
        ? Map<String, dynamic>.from(json['targetState'] as Map)
        : const {},
    easing: json['easing'] as String? ?? 'easeInOut',
    effects: {for (final e in _list(json['effects'])) '$e'},
    allowedInteractions: {
      for (final i in _list(json['allowedInteractions'])) '$i',
    },
  );
}

/// Câu hỏi dự đoán — manifest mang options là object {text} hoặc string.
class AnimationPredictionDto {
  final String question;
  final List<String> options;
  final int explainedOptionIndex;
  final String explanation;
  final String retryHint;
  final Map<String, dynamic> revealTargetState;

  const AnimationPredictionDto({
    required this.question,
    required this.options,
    required this.explainedOptionIndex,
    required this.explanation,
    this.retryHint = '',
    this.revealTargetState = const {},
  });

  factory AnimationPredictionDto.fromJson(Map json) => AnimationPredictionDto(
    question: '${json['question'] ?? ''}',
    options: [
      for (final o in _list(json['options']))
        o is Map ? '${o['text'] ?? ''}' : '$o',
    ],
    explainedOptionIndex: _int(json['explainedOptionIndex'], 0),
    explanation: '${json['explanation'] ?? ''}',
    retryHint: '${json['retryHint'] ?? ''}',
    revealTargetState: json['revealTargetState'] is Map
        ? Map<String, dynamic>.from(json['revealTargetState'] as Map)
        : const {},
  );
}

/// Một cọc trong bãi — RIVER_TIDE.
class RiverStakeDto {
  final String id;
  final double x; // normalized
  final double length; // theo h
  final bool visible;

  const RiverStakeDto({
    required this.id,
    required this.x,
    required this.length,
    this.visible = true,
  });

  factory RiverStakeDto.fromJson(Map json) => RiverStakeDto(
    id: '${json['id'] ?? ''}',
    x: _double(json['x'], 0.5),
    length: _double(json['length'], 0.2),
    visible: json['visible'] != false,
  );
}

/// Một asset reference trong manifest — resolver map sang snapshot assets[].
/// Draft `{id:<key>, assetId:<uuid>, role}`; snapshot publish thêm
/// storageKey/mimeType/altText — DTO giữ đủ cả hai dạng.
class AnimationAssetRefDto {
  final String id;
  final String assetId;
  final String role;

  const AnimationAssetRefDto({
    required this.id,
    required this.assetId,
    required this.role,
  });
}

/// P0-4 — objects[] entry: vật thể đặt trên canvas ở vị trí chuẩn hóa.
/// `assetRef` trỏ tới assets[].id — chỉ entry resolve được role OBJECT
/// mới render (role khác bị bỏ qua, không "giả vờ" cấu hình được).
class AnimationObjectDto {
  final String id;
  final String type;

  /// Tâm vật thể theo tọa độ chuẩn hóa 0..1.
  final Offset position;

  /// Đường kính vật thể theo tỉ lệ chiều rộng canvas (mặc định ~12%).
  final double scale;

  /// Thứ tự chồng lấp — cao hơn vẽ sau (trên cùng).
  final int layer;
  final bool visible;
  final String shape;

  /// v2 — góc xoay (độ, -360..360) và độ mờ (0..1) mặc định của object.
  final double rotation;
  final double opacity;

  /// Độ sâu parallax 0..1 — 0 = dính camera, 1 = dính scene. Optional.
  final double parallax;

  /// Khóa tham chiếu sang assets[].id — null khi object không gắn ảnh.
  final String? assetRef;

  const AnimationObjectDto({
    required this.id,
    required this.type,
    required this.position,
    this.scale = 0.12,
    this.layer = 0,
    this.visible = true,
    this.shape = 'rect',
    this.rotation = 0,
    this.opacity = 1,
    this.parallax = 1,
    this.assetRef,
  });

  factory AnimationObjectDto.fromJson(Map json) => AnimationObjectDto(
    id: '${json['id'] ?? ''}',
    type: '${json['type'] ?? ''}',
    position: Offset(
      _double((json['position'] as Map?)?['x'], 0.5),
      _double((json['position'] as Map?)?['y'], 0.5),
    ),
    scale: _double(json['scale'], 0.12),
    layer: _int(json['layer'], 0),
    visible: json['visible'] != false,
    shape: json['shape'] as String? ?? 'rect',
    rotation: _double(json['rotation'], 0),
    opacity: _double(json['opacity'], 1),
    parallax: _double(json['parallax'], 1),
    assetRef: json['assetRef'] as String?,
  );
}

/// v2 — camera track: pose khởi đầu + pose đích per step (theo index).
class CameraTrackDto {
  final CameraState initial;

  /// steps[i] = pose đích camera trong bước i; thiếu → giữ pose trước.
  final List<CameraState> steps;

  /// P1 §5 — easing riêng của camera.steps[i] (validator whitelist).
  /// Khi khai báo, cameraAt dùng curve này thay vì step.easing chung —
  /// camera pan/zoom có thể mượt khác với lerp trạng thái painter.
  final List<String?> easings;

  /// FIX-05 — `camera.steps[].durationMs` (ms): thời lượng RIÊNG của
  /// camera tween trong bước đó. 0/không khai báo → camera chạy cả
  /// durationMs của step (giữ semantics cũ). >0 → camera hoàn thành
  /// tween trong `durationMs` rồi GIỮ POSE cuối cho phần còn lại của
  /// bước (hold-pose semantics, khớp admin preview).
  final List<int> stepDurationsMs;

  const CameraTrackDto({
    this.initial = CameraState.initial,
    this.steps = const [],
    this.easings = const [],
    this.stepDurationsMs = const [],
  });

  factory CameraTrackDto.fromJson(Object? raw) {
    if (raw is! Map) return const CameraTrackDto();
    final rawSteps = _list(raw['steps']);
    return CameraTrackDto(
      initial: _cameraState(raw['initial']) ?? CameraState.initial,
      steps: [
        for (final s in rawSteps)
          if (s is Map) _cameraState(s['target']) ?? CameraState.initial,
      ],
      easings: [
        for (final s in rawSteps) s is Map ? s['easing'] as String? : null,
      ],
      stepDurationsMs: [
        for (final s in rawSteps) s is Map ? _int(s['durationMs'], 0) : 0,
      ],
    );
  }

  static CameraState? _cameraState(Object? raw) {
    if (raw is! Map) return null;
    return CameraState(
      center: Offset(_double(raw['x'], 0.5), _double(raw['y'], 0.5)),
      zoom: _double(raw['zoom'], 1.0).clamp(0.5, 3.0),
      focusObjectId: raw['focusObjectId'] as String?,
      focusLocationId: raw['focusLocationId'] as String?,
    );
  }
}

/// v2 — một keyframe track trên (objectId, property).
class ObjectTrackDto {
  final String objectId;
  final String property;
  final List<KeyframeSpec> keyframes;

  const ObjectTrackDto({
    required this.objectId,
    required this.property,
    this.keyframes = const [],
  });

  factory ObjectTrackDto.fromJson(Map json) => ObjectTrackDto(
    objectId: '${json['objectId'] ?? ''}',
    property: '${json['property'] ?? ''}',
    keyframes: [
      for (final k in _list(json['keyframes']))
        if (k is Map)
          KeyframeSpec(
            tMs: _int(k['tMs'], 0),
            value: _decodeValue(json['property'], k['value']),
            curve: _curve(k['easing']),
          ),
    ],
  );

  static Object _decodeValue(Object? property, Object? raw) {
    return switch ('$property') {
      'position' when raw is Map => Offset(
        _double(raw['x'], 0.5),
        _double(raw['y'], 0.5),
      ),
      'visible' => raw == true,
      _ => _double(raw, 0),
    };
  }

  static Curve _curve(Object? easing) => switch ('$easing') {
    'linear' => Curves.linear,
    'easeIn' => Curves.easeIn,
    'easeOut' => Curves.easeOut,
    'easeInOutCubic' => Curves.easeInOutCubic,
    _ => Curves.easeInOut,
  };
}

/// v2 — typed overlay effect khai báo ở scene level. `stepId` gắn
/// effect vào một bước cụ thể (rỗng/null = chạy cả scene). Params
/// bounded — đọc x/y/intensity/objectId qua getter an toàn.
class SceneEffectDto {
  final String type;

  /// Gắn vào step.id — null/rỗng nghĩa là ambient (cả scene).
  final String? stepId;
  final int durationMs;
  final Map<String, dynamic> params;

  const SceneEffectDto({
    required this.type,
    this.stepId,
    this.durationMs = 0,
    this.params = const {},
  });

  factory SceneEffectDto.fromJson(Map json) => SceneEffectDto(
    type: '${json['type'] ?? ''}',
    stepId: json['stepId'] as String?,
    durationMs: _int(json['durationMs'], 0),
    params: json['params'] is Map
        ? Map<String, dynamic>.from(json['params'] as Map)
        : const {},
  );

  /// Tọa độ chuẩn hóa trung tâm (WATER_RIPPLE/GLOW) — default giữa.
  Offset get center =>
      Offset(_double(params['x'], 0.5), _double(params['y'], 0.5));

  /// Cường độ 0..1 (MIST/GLOW) — default 0.5 để không che scene.
  double get intensity => _double(params['intensity'], 0.5).clamp(0.0, 1.0);

  /// objectId mà GLOW bám theo — null = dùng center cố định.
  String? get objectId => params['objectId'] as String?;
}

/// v2 — audio cue gắn bước: {stepId, assetRef, cue, volume, fadeMs}.
class AudioCueDto {
  final String stepId;

  /// Khóa assets[].id (role AUDIO) — resolve sang assetId khi play.
  final String assetRef;
  final String cue; // ENTER | EXIT | LOOP
  final double volume;
  final int fadeMs;

  const AudioCueDto({
    required this.stepId,
    required this.assetRef,
    required this.cue,
    this.volume = 1,
    this.fadeMs = 0,
  });

  factory AudioCueDto.fromJson(Map json) => AudioCueDto(
    stepId: '${json['stepId'] ?? ''}',
    assetRef: '${json['assetRef'] ?? ''}',
    cue: '${json['cue'] ?? 'ENTER'}',
    volume: _double(json['volume'], 1).clamp(0.0, 1.0),
    fadeMs: _int(json['fadeMs'], 0),
  );
}

/// v2 — ambient environment (RIVER_TIDE): mist/glow/waterLevel nền.
class EnvironmentDto {
  final double? waterLevel;
  final double mist;
  final double glow;

  const EnvironmentDto({this.waterLevel, this.mist = 0, this.glow = 0});

  factory EnvironmentDto.fromJson(Object? raw) {
    if (raw is! Map) return const EnvironmentDto();
    return EnvironmentDto(
      waterLevel: raw['waterLevel'] is num
          ? (raw['waterLevel'] as num).toDouble()
          : null,
      mist: _double(raw['mist'], 0).clamp(0.0, 1.0),
      glow: _double(raw['glow'], 0).clamp(0.0, 1.0),
    );
  }
}

/// Bridge: manifest → typed definition của runtime cũ — tái dùng
/// painter/player hiện có (RiverSceneState/MapSceneState lerp sẵn).
extension AnimationManifestToDefinition on AnimationManifestDto {
  /// `playbackMode` lấy từ READ config (AUTO/STEPPED/INTERACTIVE) —
  /// read_renderer truyền vào; manifest không mang field này.
  HistoricalAnimationDefinition toDefinition({String playbackMode = 'AUTO'}) {
    final steps = this.steps
        .map(
          (s) => HistoricalAnimationStep(
            label: s.title,
            narration: s.narration,
            hint: s.hint,
            target: _target(s.targetState),
            durationMs: s.durationMs > 0 ? s.durationMs : null,
            easing: s.easing,
            allowedInteractions: s.allowedInteractions,
          ),
        )
        .toList();
    return HistoricalAnimationDefinition(
      key: 'manifest_$rendererCode',
      title: title,
      learningObjective: learningObjective,
      steps: steps,
      prediction: prediction == null
          ? null
          : AnimationPrediction(
              question: prediction!.question,
              options: prediction!.options,
              explainedOptionIndex: prediction!.explainedOptionIndex,
              explanation: prediction!.explanation,
              retryHint: prediction!.retryHint,
              revealSceneEffect: _target(prediction!.revealTargetState),
              // P0 — checkpoint binding: bước nào khai báo
              // allowedInteractions ["PREDICTION"] thì khối hiển thị tại
              // bước đó (và AUTO dừng chờ). Không bước nào khai báo →
              // fallback về giữa scene (giữ hành vi khám phá trước đây:
              // không khiến prediction "không bao giờ hiện" khi manifest
              // thiếu binding tường minh).
              stepIndex: _predictionStepIndex(),
            ),
      disclaimer: disclaimer,
      sourceReference: sourceReferences.join(' · '),
      transitionDuration: transitionDuration,
      hasWaterControl: hasWaterControl,
      hasLocationExplorer: hasLocationExplorer,
      aspectRatio: canvasAspectRatio,
      playbackMode: playbackMode,
      // v2 — steps[].allowedInteractions là whitelist thuần (rỗng = bước
      // không tương tác). Scene v1 (manifestV1 / definition hardcode)
      // giữ semantics cũ: definition-level interactions áp mọi bước.
      manifestV2: schemaVersion >= 2,
      createPainter: rendererCode == 'RIVER_TIDE'
          ? () => _seedRiver(
              RiverScenePainter(
                stakes: stakes.isEmpty
                    ? null
                    : [for (final s in stakes) Offset(s.x, s.length)],
                stakeVisibility: stakes.isEmpty
                    ? null
                    : [for (final s in stakes) s.visible],
              ),
            )
          : () =>
                _seedMap(MapScenePainter(locations: locations, routes: routes)),
    );
  }

  /// Bước khai báo `allowedInteractions: ["PREDICTION"]` → index của nó;
  /// không có → fallback về bước giữa scene (không để prediction "không
  /// bao giờ hiện" khi manifest thiếu binding tường minh).
  int? _predictionStepIndex() {
    if (prediction == null || steps.isEmpty) return null;
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].allowedInteractions.contains('PREDICTION')) return i;
    }
    return (steps.length - 1) ~/ 2;
  }

  /// Áp manifest.initialState lên painter vừa tạo — key nào thiếu giữ
  /// default của painter, key lạ bị bỏ qua (whitelist implicit qua tên
  /// field đã biết). Bước 0 tween từ đây thay vì default hard-code.
  /// v2 — environment.waterLevel seed TRƯỚC initialState (thấp hơn
  /// priority): `initialState.waterLevel` vẫn override nếu khai báo.
  RiverScenePainter _seedRiver(RiverScenePainter p) {
    final envWater = environment.waterLevel;
    if (envWater != null) p.waterLevel = envWater;
    final s = initialState;
    if (s.isEmpty) return p;
    if (s['waterLevel'] is num) {
      p.waterLevel = (s['waterLevel'] as num).toDouble();
    }
    if (s['boatProgress'] is num) {
      p.boatProgress = (s['boatProgress'] as num).toDouble();
    }
    if (s['decoyProgress'] is num) {
      p.decoyProgress = (s['decoyProgress'] as num).toDouble();
    }
    if (s['counterattackProgress'] is num) {
      p.counterattackProgress = (s['counterattackProgress'] as num).toDouble();
    }
    if (s['obstructed'] == true) p.boatsObstructed = true;
    if (s['highlightStakes'] == true) p.highlightStakes = true;
    if (s['showSequenceSummary'] == true) p.showSequenceSummary = true;
    return p;
  }

  MapScenePainter _seedMap(MapScenePainter p) {
    final s = initialState;
    if (s.isEmpty) return p;
    p.markerVisibility = _numMap(s['markerVisibility']);
    p.routeProgress = _numMap(s['routeProgress']);
    p.highlightedIds = {
      for (final h in _list(s['markerHighlight'] ?? s['highlighted'])) '$h',
    };
    if (s['focusedLocationId'] is String) {
      p.focusedId = s['focusedLocationId'] as String;
    }
    return p;
  }

  /// Decode targetState JSON → typed SceneTransition theo renderer.
  SceneTransition? _target(Map<String, dynamic> s) {
    if (s.isEmpty) return null;
    if (rendererCode == 'RIVER_TIDE') {
      return RiverSceneState(
        waterLevel: _double(s['waterLevel'], 0.3),
        boatProgress: _double(s['boatProgress'], 0),
        boatsObstructed: s['obstructed'] == true,
        highlightStakes: s['highlightStakes'] == true,
        decoyProgress: _double(s['decoyProgress'], 0),
        counterattackProgress: _double(s['counterattackProgress'], 0),
        showSequenceSummary: s['showSequenceSummary'] == true,
      );
    }
    if (rendererCode == 'JOURNEY_MAP') {
      return MapSceneState(
        markerVisibility: _numMap(s['markerVisibility']),
        routeProgress: _numMap(s['routeProgress']),
        highlighted: {
          for (final h in _list(s['markerHighlight'] ?? s['highlighted'])) '$h',
        },
        focusedId: s['focusedLocationId'] as String?,
      );
    }
    return null;
  }
}

Map<String, double> _numMap(Object? raw) => {
  if (raw is Map)
    for (final e in raw.entries) '${e.key}': _double(e.value, 0),
};

List<dynamic> _list(Object? raw) => raw is List ? raw : const [];
int _int(Object? v, int d) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? d);
double _double(Object? v, double d) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? d;
