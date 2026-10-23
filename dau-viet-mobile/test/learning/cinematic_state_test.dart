import 'package:dau_viet_mobile/features/learning/presentation/animations/runtime/cinematic_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// v2 — unit tests cho evaluators thuần Dart: deterministic, không cần
/// widget. Parity: cùng công thức phải khớp admin `cinematic-eval.ts`.
void main() {
  group('CameraState', () {
    test('lerp interpolates center and zoom', () {
      const a = CameraState(center: Offset(0, 0), zoom: 1);
      const b = CameraState(center: Offset(1, 1), zoom: 2);
      final m = a.lerp(b, 0.5);
      expect(m.center, const Offset(0.5, 0.5));
      expect(m.zoom, closeTo(1.5, 1e-9));
      expect(a.lerp(b, 0).zoom, 1);
      expect(a.lerp(b, 1).zoom, 2);
    });

    test('transformFor scales around normalized center', () {
      const cam = CameraState(center: Offset(0.5, 0.5), zoom: 2);
      final m = cam.transformFor(const Size(100, 100));
      // Camera ở giữa + zoom 2 → điểm giữa canvas giữ nguyên.
      final v = MatrixUtils.transformPoint(m, const Offset(50, 50));
      expect(v.dx, closeTo(50, 1e-6));
      expect(v.dy, closeTo(50, 1e-6));
    });
  });

  group('ObjectTrackSpec.valueAt', () {
    final track = ObjectTrackSpec(
      objectId: 'boat',
      property: 'position',
      keyframes: const [
        KeyframeSpec(tMs: 0, value: Offset(0.9, 0.4), curve: Curves.linear),
        KeyframeSpec(tMs: 1000, value: Offset(0.5, 0.4), curve: Curves.linear),
      ],
    );

    test('before first keyframe returns first value', () {
      expect(track.valueAt(-5, const Offset(0, 0)), const Offset(0.9, 0.4));
    });

    test('after last keyframe returns last value', () {
      expect(track.valueAt(5000, const Offset(0, 0)), const Offset(0.5, 0.4));
    });

    test('midpoint lerps linearly', () {
      final v = track.valueAt(500, const Offset(0, 0)) as Offset;
      expect(v.dx, closeTo(0.7, 1e-9));
      expect(v.dy, 0.4);
    });

    test('visible toggles at threshold', () {
      final t = ObjectTrackSpec(
        objectId: 'o',
        property: 'visible',
        keyframes: const [
          KeyframeSpec(tMs: 0, value: false),
          KeyframeSpec(tMs: 100, value: true),
        ],
      );
      expect(t.valueAt(0, true), false);
      expect(t.valueAt(100, false), true);
    });
  });

  group('CinematicEvaluator', () {
    final ev = CinematicEvaluator(
      cameraInitial: const CameraState(center: Offset(0.5, 0.5), zoom: 1),
      cameraSteps: const [
        CameraState(center: Offset(0.6, 0.6), zoom: 1.5),
        CameraState(center: Offset(0.4, 0.5), zoom: 1.0),
      ],
      stepDurationsMs: const [1000, 2000],
      baseObjects: const {
        'boat': ObjectVisualState(position: Offset(0.9, 0.4), scale: 0.12),
      },
      tracks: const [
        ObjectTrackSpec(
          objectId: 'boat',
          property: 'position',
          keyframes: [
            KeyframeSpec(tMs: 0, value: Offset(0.9, 0.4), curve: Curves.linear),
            KeyframeSpec(
              tMs: 3000,
              value: Offset(0.3, 0.4),
              curve: Curves.linear,
            ),
          ],
        ),
      ],
    );

    test('globalTMs sums prior step durations', () {
      expect(ev.globalTMs(0, 0), 0);
      expect(ev.globalTMs(0, 0.5), 500);
      expect(ev.globalTMs(1, 0), 1000);
      expect(ev.globalTMs(1, 1), 3000);
    });

    test('cameraAt lerps step poses', () {
      final mid = ev.cameraAt(0, 0.5);
      expect(mid.zoom, closeTo(1.25, 1e-9));
      // Step 1 bắt đầu từ pose cuối step 0.
      final s1 = ev.cameraAt(1, 0);
      expect(s1.zoom, closeTo(1.5, 1e-9));
    });

    test('frameAt combines camera + object state at global tMs', () {
      final f = ev.frameAt(1, 0.5, 0.5); // tMs = 1000 + 1000 = 2000
      final boat = f.objects['boat']!;
      // tMs 2000 / 3000 → x = 0.9 - 0.6*(2/3) = 0.5
      expect(boat.position.dx, closeTo(0.5, 1e-9));
    });

    test('frameEndAt returns final pose for reduced-motion', () {
      final f = ev.frameEndAt(1);
      expect(f.camera.zoom, closeTo(1.0, 1e-9));
      final boat = f.objects['boat']!;
      expect(boat.position.dx, closeTo(0.3, 1e-9));
    });
  });

  /* ---------- FIX-P1 §3 — camera easing override semantics ----------
     Parity với cinematic-eval.test.ts: override áp trên RAW progress
     đúng 1 lần; không override → dùng easedT của step.easing. */
  group('CinematicEvaluator camera easing override (FIX-P1)', () {
    // Camera ban đầu 0→1 trên x (đích step 0: x=1, zoom=2).
    const camInitial = CameraState(center: Offset(0, 0.5), zoom: 1);
    const camSteps = [
      CameraState(center: Offset(1, 0.5), zoom: 2),
      CameraState(center: Offset(0, 0.5), zoom: 1),
    ];

    CinematicEvaluator mk({
      List<Curve?> easings = const [],
      List<int> camDurMs = const [],
      List<int> stepDurMs = const [2000, 2000],
      List<Curve?> stepEasings = const [],
    }) => CinematicEvaluator(
      cameraInitial: camInitial,
      cameraSteps: camSteps,
      cameraEasings: easings,
      cameraStepDurationsMs: camDurMs,
      stepDurationsMs: stepDurMs,
      stepEasings: stepEasings,
    );

    test('camera.easing override nội suy trên RAW, không double-ease', () {
      // step.easing=easeOut → caller truyền easedT = easeOut(0.5) = 0.75.
      // camera.easing=linear → camT = raw = 0.5 → x = 0.5 (không phải 0.75).
      final ev = mk(easings: const [Curves.linear]);
      final f = ev.cameraAtRaw(0, 0.75, 0.5);
      expect(f.center.dx, closeTo(0.5, 1e-9));
    });

    test('step linear + camera easeIn → easeIn áp 1 lần trên raw', () {
      // step linear → easedT = raw; camera easeIn → camT = easeIn(raw).
      // Lưu ý: Curves.easeIn của Flutter là cubic-bezier (0.42,0,1,1),
      // khác x² của TS easeValue — nhưng contract giống nhau (override
      // áp lên raw đúng 1 lần) nên expected tính từ cùng Curve object.
      final ev = mk(easings: const [Curves.easeIn]);
      for (final raw in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final f = ev.cameraAtRaw(0, raw, raw);
        expect(
          f.center.dx,
          closeTo(Curves.easeIn.transform(raw), 1e-5),
          reason: 'raw=$raw',
        );
      }
    });

    test('step easeOut + camera linear → camera linear trên raw', () {
      // easedT = easeOut(raw); camera linear → camT = raw.
      final ev = mk(easings: const [Curves.linear]);
      for (final raw in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final easedT = Curves.easeOut.transform(raw);
        final f = ev.cameraAtRaw(0, easedT, raw);
        expect(f.center.dx, closeTo(raw, 1e-5), reason: 'raw=$raw');
      }
    });

    test('step easeInOut + camera easeOut → camera easeOut trên raw', () {
      final ev = mk(easings: const [Curves.easeOut]);
      for (final raw in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final easedT = Curves.easeInOut.transform(raw);
        final f = ev.cameraAtRaw(0, easedT, raw);
        expect(
          f.center.dx,
          closeTo(Curves.easeOut.transform(raw), 1e-5),
          reason: 'raw=$raw',
        );
      }
    });

    test(
      'camDur<stepDur + camera.easing → ease 1 lần trong window rồi hold',
      () {
        // step=2000ms, camera=500ms → cap=0.25. camera.easing=easeIn.
        final ev = mk(
          easings: const [Curves.easeIn],
          camDurMs: const [500],
          stepDurMs: const [2000],
        );
        // raw 0.125 (nửa window) → inTween=0.5 → easeIn(0.5) → x=easeIn(0.5).
        expect(
          ev.cameraAtRaw(0, 0.125, 0.125).center.dx,
          closeTo(Curves.easeIn.transform(0.5), 1e-5),
        );
        // raw 0.5 (sau cap) → hold pose cuối x=1.
        expect(ev.cameraAtRaw(0, 0.5, 0.5).center.dx, closeTo(1.0, 1e-9));
        expect(ev.cameraAtRaw(0, 0.9, 0.9).center.dx, closeTo(1.0, 1e-9));
      },
    );

    test('camDur<stepDur KHÔNG camera.easing → step.easing(inTween), '
        'không linear', () {
      // step.easing=easeIn, camDur=500/2000 → cap=0.25. raw 0.125 →
      // inTween=0.5 → easeIn(0.5) (Flutter cubic, ≠0.5 linear).
      final ev = mk(
        camDurMs: const [500],
        stepDurMs: const [2000],
        stepEasings: const [Curves.easeIn],
      );
      expect(
        ev.cameraAtRaw(0, 0.5, 0.125).center.dx,
        closeTo(Curves.easeIn.transform(0.5), 1e-5),
      );
      // Sau cap → hold pose cuối x=1.
      expect(ev.cameraAtRaw(0, 1.0, 0.6).center.dx, closeTo(1.0, 1e-9));
    });

    test('camDur<stepDur + step easeOut no override → easeOut(inTween)', () {
      final ev = mk(
        camDurMs: const [500],
        stepDurMs: const [2000],
        stepEasings: const [Curves.easeOut],
      );
      for (final raw in const [0.0, 0.125, 0.25]) {
        final inTween = (raw / 0.25).clamp(0.0, 1.0);
        final easedT = Curves.easeOut.transform(raw);
        expect(
          ev.cameraAtRaw(0, easedT, raw).center.dx,
          closeTo(Curves.easeOut.transform(inTween), 1e-5),
          reason: 'raw=$raw',
        );
      }
    });

    test('camDur==stepDur → tween cả step (không override → easedT)', () {
      final ev = mk(
        camDurMs: const [2000],
        stepDurMs: const [2000],
        stepEasings: const [Curves.easeIn],
      );
      // camDur==stepDur → nhánh full-step: camT = easedT caller truyền.
      expect(ev.cameraAtRaw(0, 0.5, 0.5).center.dx, closeTo(0.5, 1e-9));
    });

    test('stepEasings rỗng + camDur → linear fallback (compat cũ)', () {
      // Manifest cũ không stepEasings → fallback Curves.linear giữ
      // hành vi trước FIX-P1 §3.
      final ev = mk(camDurMs: const [500], stepDurMs: const [2000]);
      expect(ev.cameraAtRaw(0, 0.5, 0.125).center.dx, closeTo(0.5, 1e-9));
    });

    test('không camera.easing → camera dùng easedT của step', () {
      final ev = mk();
      // Caller truyền easedT = 0.5 (đã qua step.easing); camT = easedT.
      expect(ev.cameraAtRaw(0, 0.5, 0.2).center.dx, closeTo(0.5, 1e-9));
    });

    test('cameraAt(t) cũ = cameraAtRaw(t, t) — v1 không đổi hành vi', () {
      final ev = mk(easings: const [Curves.easeIn]);
      for (final t in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final a = ev.cameraAt(0, t);
        final b = ev.cameraAtRaw(0, t, t);
        expect(a.center, b.center);
        expect(a.zoom, b.zoom);
      }
    });
  });

  group('CinematicEvaluator.effectsAt', () {
    final ev = CinematicEvaluator(
      stepIds: const ['s1', 's2'],
      stepDurationsMs: const [1000, 2000],
      effects: const [
        // Ambient — không stepId → chạy cả scene.
        SceneEffectSpec(type: 'MIST', intensity: 0.4),
        // Step-bound — chỉ active trong step s2.
        SceneEffectSpec(
          type: 'GLOW',
          stepId: 's2',
          center: Offset(0.3, 0.3),
          intensity: 0.7,
        ),
        // Timed — durationMs 500 trong step 2000ms.
        SceneEffectSpec(type: 'WATER_RIPPLE', stepId: 's2', durationMs: 500),
        // Effect gắn step không tồn tại — không bao giờ emit.
        SceneEffectSpec(type: 'FADE_IN', stepId: 'nope'),
      ],
    );

    test('ambient effect runs in every step', () {
      final f0 = ev.effectsAt(0, 0.5);
      expect(f0.any((e) => e.type == 'MIST'), isTrue);
      final f1 = ev.effectsAt(1, 0.5);
      expect(f1.any((e) => e.type == 'MIST'), isTrue);
    });

    test('step-bound effect only fires on matching stepId', () {
      final f0 = ev.effectsAt(0, 0.5);
      expect(f0.any((e) => e.type == 'GLOW'), isFalse);
      final f1 = ev.effectsAt(1, 0.5);
      final glow = f1.firstWhere((e) => e.type == 'GLOW');
      expect(glow.center, const Offset(0.3, 0.3));
      expect(glow.intensity, 0.7);
    });

    test('timed effect progress = stepElapsed / durationMs', () {
      // Step 1, rawProgress 0.25 → elapsed 500ms / duration 500ms → 1.0.
      final f = ev.effectsAt(1, 0.25);
      final ripple = f.firstWhere((e) => e.type == 'WATER_RIPPLE');
      expect(ripple.progress, closeTo(1.0, 1e-9));
      // rawProgress 0.125 → elapsed 250ms / 500ms → 0.5.
      final f2 = ev.effectsAt(1, 0.125);
      expect(
        f2.firstWhere((e) => e.type == 'WATER_RIPPLE').progress,
        closeTo(0.5, 1e-9),
      );
    });

    test('unknown stepId never emits', () {
      for (var i = 0; i < 2; i++) {
        expect(ev.effectsAt(i, 0.5).any((e) => e.type == 'FADE_IN'), isFalse);
      }
    });
  });
}
