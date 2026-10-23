import 'package:flutter/material.dart';

import '../scenes/historical_map_scene.dart';
import '../scenes/river_scene.dart';
import '../historical_animation_definition.dart';

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
  });

  /// Parse embedded manifest — field thiếu/sai nhận default an toàn,
  /// không throw (app cũ đọc manifest mới vẫn render phần đọc được).
  factory AnimationManifestDto.fromJson(Map<String, dynamic> json) {
    final map = json['map'];
    final river = json['river'];
    return AnimationManifestDto(
      schemaVersion: _int(json['schemaVersion'], 1),
      rendererCode: json['rendererCode'] as String? ?? '',
      rendererVersion: _int(json['rendererVersion'], 1),
      title: json['title'] as String? ?? '',
      learningObjective: json['learningObjective'] as String? ?? '',
      canvasAspectRatio:
          _double((json['canvas'] as Map?)?['aspectRatio'], 16 / 10),
      steps: _steps(json['steps']),
      prediction: _prediction(json['prediction']),
      interactions: {
        for (final i in _list(json['interactions'])) '$i',
      },
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
    );
  }

  bool get hasWaterControl =>
      interactions.contains('WATER_LEVEL_CONTROL');
  bool get hasLocationExplorer => interactions.contains('TAP_TO_EXPLORE');

  static List<AnimationStepDto> _steps(Object? raw) => [
        for (final s in _list(raw))
          if (s is Map) AnimationStepDto.fromJson(s),
      ];

  static AnimationPredictionDto? _prediction(Object? raw) =>
      raw is Map ? AnimationPredictionDto.fromJson(raw) : null;

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

/// Bridge: manifest → typed definition của runtime cũ — tái dùng
/// painter/player hiện có (RiverSceneState/MapSceneState lerp sẵn).
extension AnimationManifestToDefinition on AnimationManifestDto {
  HistoricalAnimationDefinition toDefinition() {
    final steps = this.steps
        .map(
          (s) => HistoricalAnimationStep(
            label: s.title,
            narration: s.narration,
            hint: s.hint,
            target: _target(s.targetState),
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
            ),
      disclaimer: disclaimer,
      sourceReference: sourceReferences.join(' · '),
      transitionDuration: transitionDuration,
      hasWaterControl: hasWaterControl,
      hasLocationExplorer: hasLocationExplorer,
      createPainter: rendererCode == 'RIVER_TIDE'
          ? () => _seedRiver(RiverScenePainter(
                stakes: stakes.isEmpty
                    ? null
                    : [for (final s in stakes) Offset(s.x, s.length)],
                stakeVisibility: stakes.isEmpty
                    ? null
                    : [for (final s in stakes) s.visible],
              ))
          : () => _seedMap(
              MapScenePainter(locations: locations, routes: routes)),
    );
  }

  /// Áp manifest.initialState lên painter vừa tạo — key nào thiếu giữ
  /// default của painter, key lạ bị bỏ qua (whitelist implicit qua tên
  /// field đã biết). Bước 0 tween từ đây thay vì default hard-code.
  RiverScenePainter _seedRiver(RiverScenePainter p) {
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
      p.counterattackProgress =
          (s['counterattackProgress'] as num).toDouble();
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
      for (final h in _list(s['markerHighlight'] ?? s['highlighted']))
        '$h',
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
          for (final h in _list(s['markerHighlight'] ?? s['highlighted']))
            '$h',
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
