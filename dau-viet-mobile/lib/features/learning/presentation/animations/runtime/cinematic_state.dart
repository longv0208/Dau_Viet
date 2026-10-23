import 'package:flutter/material.dart';

/// Cinematic v2 — pure-Dart evaluators cho camera + keyframe tracks.
/// Không phụ thuộc widget/painter — deterministic, unit-testable.
///
/// Parity contract: `dau-viet-admin/.../preview/cinematic-eval.ts` là bản
/// port TS của các hàm này — mọi thay đổi công thức phải cập nhật cả hai.

/// Tư thế camera tại một thời điểm — tọa độ tâm chuẩn hóa 0..1 trong
/// không gian canvas (không phải pixel), zoom tỉ lệ.
class CameraState {
  /// Tâm viewport theo tọa độ chuẩn hóa (0.5,0.5 = giữa canvas).
  final Offset center;
  final double zoom;

  /// Node mà camera đang focus — chỉ là metadata (preview/label); pan
  /// được resolve thành [center] bởi controller, không lưu trạng thái.
  final String? focusObjectId;
  final String? focusLocationId;

  const CameraState({
    this.center = const Offset(0.5, 0.5),
    this.zoom = 1.0,
    this.focusObjectId,
    this.focusLocationId,
  });

  static const initial = CameraState();

  CameraState lerp(CameraState to, double t) => CameraState(
    center: Offset.lerp(center, to.center, t) ?? to.center,
    zoom: zoom + (to.zoom - zoom) * t,
    focusObjectId: t < 1 ? focusObjectId : to.focusObjectId,
    focusLocationId: t < 1 ? focusLocationId : to.focusLocationId,
  );

  /// Ma trận transform áp lên canvas: scale quanh [center] của viewport.
  /// [size] là kích thước widget thật (px).
  Matrix4 transformFor(Size size) {
    final px = center.dx * size.width;
    final py = center.dy * size.height;
    return Matrix4.identity()
      ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
      ..scaleByDouble(zoom, zoom, zoom, 1)
      ..translateByDouble(-px, -py, 0, 1);
  }
}

/// Trạng thái hình ảnh đầy đủ của một object tại một thời điểm — kết
/// hợp giá trị mặc định từ objects[] với override từ keyframe tracks.
class ObjectVisualState {
  final Offset position;
  final double scale;
  final double rotation;
  final double opacity;
  final bool visible;

  const ObjectVisualState({
    required this.position,
    this.scale = 0.12,
    this.rotation = 0,
    this.opacity = 1,
    this.visible = true,
  });

  ObjectVisualState copyWith({
    Offset? position,
    double? scale,
    double? rotation,
    double? opacity,
    bool? visible,
  }) => ObjectVisualState(
    position: position ?? this.position,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    opacity: opacity ?? this.opacity,
    visible: visible ?? this.visible,
  );

  ObjectVisualState lerp(ObjectVisualState to, double t) => ObjectVisualState(
    position: Offset.lerp(position, to.position, t) ?? to.position,
    scale: scale + (to.scale - scale) * t,
    rotation: rotation + (to.rotation - rotation) * t,
    opacity: opacity + (to.opacity - opacity) * t,
    visible: t < 1 ? visible : to.visible,
  );
}

/// Một keyframe trên timeline cảnh — [tMs] tuyệt đối tính từ đầu scene.
class KeyframeSpec {
  final int tMs;

  /// Giá trị đích — kiểu tùy property: Offset (position), double
  /// (scale/rotation/opacity), bool (visible).
  final Object value;
  final Curve curve;

  const KeyframeSpec({
    required this.tMs,
    required this.value,
    this.curve = Curves.easeInOut,
  });
}

/// Một track gắn (objectId, property) → dãy keyframe tMs tăng dần.
class ObjectTrackSpec {
  final String objectId;
  final String property;
  final List<KeyframeSpec> keyframes;

  const ObjectTrackSpec({
    required this.objectId,
    required this.property,
    required this.keyframes,
  });

  /// Giá trị của property tại [tMs] — nội suy giữa hai keyframe bao
  /// quanh; trước key đầu giữ giá trị key đầu, sau key cuối giữ key cuối.
  /// `base` là giá trị mặc định của object (dùng khi track không có key
  /// trước tMs — deterministic, không phụ thuộc frame đã chạy).
  Object valueAt(int tMs, Object base) {
    final ks = keyframes;
    if (ks.isEmpty) return base;
    if (tMs <= ks.first.tMs) return ks.first.value;
    if (tMs >= ks.last.tMs) return ks.last.value;
    for (var i = 0; i < ks.length - 1; i++) {
      final a = ks[i];
      final b = ks[i + 1];
      if (tMs >= a.tMs && tMs <= b.tMs) {
        final span = b.tMs - a.tMs;
        final raw = span <= 0 ? 1.0 : (tMs - a.tMs) / span;
        final t = b.curve.transform(raw.clamp(0.0, 1.0));
        return _lerpValue(a.value, b.value, t);
      }
    }
    return ks.last.value;
  }

  static Object _lerpValue(Object a, Object b, double t) {
    if (a is Offset && b is Offset) {
      return Offset.lerp(a, b, t) ?? b;
    }
    if (a is double && b is double) return a + (b - a) * t;
    if (a is num && b is num) {
      return a.toDouble() + (b.toDouble() - a.toDouble()) * t;
    }
    // bool hoặc kiểu không lerp được — bật tại ngưỡng 0.5.
    return t < 0.5 ? a : b;
  }
}

/// Toàn bộ trạng thái cinematic tại thời điểm tMs — camera + trạng thái
/// hình ảnh của mọi object có track. Được player tính mỗi tick và đưa
/// cho ManifestAssetLayers/effects render.
class CinematicFrame {
  final CameraState camera;
  final Map<String, ObjectVisualState> objects;

  /// v2 — effect overlays đã resolve cho thời điểm này (type + params
  /// đọc được qua SceneEffectDto; progress fade/ripple do player tính).
  final List<ActiveEffect> effects;

  const CinematicFrame({
    required this.camera,
    this.objects = const {},
    this.effects = const [],
  });
}

/// Effect đang active tại frame — type + progress 0..1 của riêng nó.
class ActiveEffect {
  final String type;
  final Offset center;
  final double intensity;
  final String? objectId;
  final double progress;

  const ActiveEffect({
    required this.type,
    this.center = const Offset(0.5, 0.5),
    this.intensity = 0.5,
    this.objectId,
    this.progress = 1,
  });
}

/// Evaluator tổng — tính [CinematicFrame] tại tMs từ camera track +
/// object tracks + giá trị mặc định objects[]. Thuần hàm (tMs, specs) →
/// frame: deterministic seek/replay.
class CinematicEvaluator {
  /// Camera poses per step index — `steps[i]` tween từ pose bước i-1
  /// (hoặc initial khi i == 0) tới pose i trong durationMs của bước.
  final CameraState cameraInitial;
  final List<CameraState> cameraSteps;
  final List<ObjectTrackSpec> tracks;

  /// Trạng thái mặc định của từng object (từ manifest objects[]).
  final Map<String, ObjectVisualState> baseObjects;

  /// durationMs từng step — dùng để map (stepIndex, stepProgressMs) →
  /// tMs toàn cục và ngược lại.
  final List<int> stepDurationsMs;

  /// v2 — stepId per index (để match `effects[].stepId`) + effect specs
  /// scene-level. Effect không có stepId (null/rỗng) = ambient cả scene.
  final List<String> stepIds;
  final List<SceneEffectSpec> effects;

  /// P1 §5 — `camera.steps[].easing` whitelist → curve riêng cho camera
  /// tween (index-aligned với cameraSteps). Null/missing = dùng easedT
  /// caller truyền (tức step.easing chung).
  final List<Curve?> cameraEasings;

  /// FIX-05 — `camera.steps[].durationMs` (index-aligned). >0 → camera
  /// tween hoàn thành trong `durationMs` ms đầu của bước rồi GIỮ POSE
  /// cuối cho phần còn lại (hold-pose); 0/vắng = camera chạy cả bước
  /// như cũ. Parity với TS `cameraStepDurationsMs` trong cinematic-eval.
  final List<int> cameraStepDurationsMs;

  const CinematicEvaluator({
    this.cameraInitial = CameraState.initial,
    this.cameraSteps = const [],
    this.tracks = const [],
    this.baseObjects = const {},
    this.stepDurationsMs = const [],
    this.stepIds = const [],
    this.effects = const [],
    this.cameraEasings = const [],
    this.cameraStepDurationsMs = const [],
  });

  /// tMs toàn cục = tổng duration các bước đã xong + tiến độ trong bước
  /// hiện tại (progress 0..1 × duration bước).
  int globalTMs(int stepIndex, double stepProgress) {
    var acc = 0;
    for (var i = 0; i < stepIndex && i < stepDurationsMs.length; i++) {
      acc += stepDurationsMs[i];
    }
    if (stepIndex < stepDurationsMs.length) {
      acc += (stepDurationsMs[stepIndex] * stepProgress.clamp(0.0, 1.0))
          .round();
    }
    return acc;
  }

  /// Camera pose tại (stepIndex, t eased 0..1 trong bước): lerp từ pose
  /// trước tới cameraSteps[stepIndex] (hoặc giữ pose cuối nếu bước không
  /// khai báo camera). Khi `cameraEasings[idx]` có → transform `t` lại
  /// bằng curve đó (override step.easing cho riêng camera).
  ///
  /// FIX-05 — `cameraStepDurationsMs[idx]` > 0: camera hoàn thành tween
  /// trong khoảng đó (ms đầu bước) rồi GIỮ POSE cuối — rawProgress của
  /// bước chạy đầy đủ nhưng camera clamp t ở `camDuration / stepDuration`.
  CameraState cameraAt(int stepIndex, double t) {
    return cameraAtRaw(stepIndex, t, t);
  }

  /// Tách riêng easedT (cho scene-state painter) và rawProgress (cho
  /// camera-duration clamp) — player gọi với cả hai; TS port giữ API
  /// `cameraAt(spec, stepIndex, easedT, rawProgress)` tương đương.
  CameraState cameraAtRaw(int stepIndex, double easedT, double rawProgress) {
    if (cameraSteps.isEmpty) return cameraInitial;
    final idx = stepIndex.clamp(0, cameraSteps.length - 1);
    final from = idx == 0 ? cameraInitial : cameraSteps[idx - 1];
    final to = cameraSteps[idx];
    final override = idx < cameraEasings.length ? cameraEasings[idx] : null;
    var camT = override != null
        ? override.transform(easedT.clamp(0.0, 1.0))
        : easedT; // easedT = caller-đã-ease (step.easing) khi không override
    // FIX-05 — camera duration ngắn hơn step → tween xong sớm, giữ pose.
    final camDur = idx < cameraStepDurationsMs.length
        ? cameraStepDurationsMs[idx]
        : 0;
    final stepDur = idx < stepDurationsMs.length ? stepDurationsMs[idx] : 0;
    if (camDur > 0 && stepDur > 0 && camDur < stepDur) {
      // Normalize raw progress vào phạm vi tween [0..camDur] rồi mới
      // ease — sau ngưỡng camDur, camT = curve(1) giữ pose cuối. Khi
      // không có override (cameraEasings[idx] = null), step-easing đã
      // được caller áp lên `easedT` → un-ease không khả thi; giữ camT
      // theo raw-progress scale là xấp xỉ đúng đủ cho preview (parity
      // TS cùng hành vi — manifest không khai báo camera.easing thì
      // camera tween theo step easing trên cửa sổ con).
      final cap = camDur / stepDur;
      final rawInTween = (rawProgress / cap).clamp(0.0, 1.0);
      camT = override != null ? override.transform(rawInTween) : rawInTween;
    }
    return from.lerp(to, camT.clamp(0.0, 1.0));
  }

  /// Camera pose CUỐI của bước (t=1) — dùng cho reduced-motion/skip.
  CameraState cameraEndAt(int stepIndex) => cameraAt(stepIndex, 1.0);

  /// Trạng thái hình ảnh của mọi object có base/track tại tMs.
  Map<String, ObjectVisualState> objectsAt(int tMs) {
    if (baseObjects.isEmpty && tracks.isEmpty) return const {};
    final out = <String, ObjectVisualState>{};
    baseObjects.forEach((id, base) => out[id] = base);
    for (final track in tracks) {
      final base = out[track.objectId];
      if (base == null) continue;
      final v = track.valueAt(tMs, _baseValue(base, track.property));
      out[track.objectId] = _apply(base, track.property, v);
    }
    return out;
  }

  /// Frame đầy đủ tại (stepIndex, t eased, stepProgress thô 0..1).
  CinematicFrame frameAt(int stepIndex, double easedT, double rawProgress) {
    final tMs = globalTMs(stepIndex, rawProgress);
    return CinematicFrame(
      camera: cameraAtRaw(stepIndex, easedT, rawProgress),
      objects: objectsAt(tMs),
      effects: effectsAt(stepIndex, rawProgress),
    );
  }

  /// Effects active tại (stepIndex, rawProgress) — scene-level `effects[]`
  /// lọc theo stepId khớp (hoặc ambient khi stepId trống). `progress` của
  /// effect = rawProgress trong bước khi durationMs <= 0 (chạy cả bước),
  /// hoặc tMs/durationMs khi khai báo rõ (effect ngắn hơn bước).
  List<ActiveEffect> effectsAt(int stepIndex, double rawProgress) {
    if (effects.isEmpty) return const [];
    final sid = stepIndex < stepIds.length ? stepIds[stepIndex] : null;
    final dur = stepIndex < stepDurationsMs.length
        ? stepDurationsMs[stepIndex]
        : 0;
    final out = <ActiveEffect>[];
    for (final e in effects) {
      final isAmbient = e.stepId == null || e.stepId!.isEmpty;
      if (!isAmbient && e.stepId != sid) continue;
      double p = rawProgress;
      if (e.durationMs > 0 && dur > 0) {
        p = ((rawProgress * dur) / e.durationMs).clamp(0.0, 1.0);
      }
      out.add(
        ActiveEffect(
          type: e.type,
          center: e.center,
          intensity: e.intensity,
          objectId: e.objectId,
          progress: p,
        ),
      );
    }
    return out;
  }

  /// Frame CUỐI của bước — reduced-motion/skip nhảy thẳng đây.
  CinematicFrame frameEndAt(int stepIndex) => frameAt(stepIndex, 1.0, 1.0);

  static Object _baseValue(ObjectVisualState s, String property) =>
      switch (property) {
        'position' => s.position,
        'scale' => s.scale,
        'rotation' => s.rotation,
        'opacity' => s.opacity,
        'visible' => s.visible,
        _ => s.opacity,
      };

  static ObjectVisualState _apply(
    ObjectVisualState s,
    String property,
    Object v,
  ) => switch (property) {
    'position' => s.copyWith(position: v as Offset),
    'scale' => s.copyWith(scale: (v as num).toDouble()),
    'rotation' => s.copyWith(rotation: (v as num).toDouble()),
    'opacity' => s.copyWith(opacity: (v as num).toDouble()),
    'visible' => s.copyWith(visible: v as bool),
    _ => s,
  };
}

/// v2 — spec cho một scene effect (đã giải param sang typed values).
/// Tách khỏi DTO để evaluator thuần Dart, không phụ thuộc manifest DTO.
class SceneEffectSpec {
  final String type;
  final String? stepId;
  final int durationMs;
  final Offset center;
  final double intensity;
  final String? objectId;

  const SceneEffectSpec({
    required this.type,
    this.stepId,
    this.durationMs = 0,
    this.center = const Offset(0.5, 0.5),
    this.intensity = 0.5,
    this.objectId,
  });
}
