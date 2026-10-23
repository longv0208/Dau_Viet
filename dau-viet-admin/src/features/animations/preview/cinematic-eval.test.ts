import { describe, expect, it } from "vitest";

import {
  CAMERA_INITIAL,
  cameraAt,
  effectsAt,
  frameAt,
  frameEndAt,
  globalTMs,
  lerpCamera,
  objectsAt,
  trackValueAt,
  type EvaluatorSpec,
  type ObjectTrackSpec,
} from "./cinematic-eval";

/** Parity tests — khớp test/learning/cinematic_state_test.dart bên mobile. */

describe("camera", () => {
  it("lerps center + zoom", () => {
    const m = lerpCamera(
      { center: { x: 0, y: 0 }, zoom: 1 },
      { center: { x: 1, y: 1 }, zoom: 2 },
      0.5,
    );
    expect(m.center).toEqual({ x: 0.5, y: 0.5 });
    expect(m.zoom).toBeCloseTo(1.5);
  });

  it("cameraAt lerps between step poses", () => {
    const steps = [
      { center: { x: 0.6, y: 0.6 }, zoom: 1.5 },
      { center: { x: 0.4, y: 0.5 }, zoom: 1 },
    ];
    const mid = cameraAt(CAMERA_INITIAL, steps, 0, 0.5);
    expect(mid.zoom).toBeCloseTo(1.25);
    const s1 = cameraAt(CAMERA_INITIAL, steps, 1, 0);
    expect(s1.zoom).toBeCloseTo(1.5); // bắt đầu từ pose cuối step 0
  });
});

describe("trackValueAt", () => {
  const track: ObjectTrackSpec = {
    objectId: "boat",
    property: "position",
    keyframes: [
      { tMs: 0, value: { x: 0.9, y: 0.4 }, easing: "linear" },
      { tMs: 1000, value: { x: 0.5, y: 0.4 }, easing: "linear" },
    ],
  };

  it("clamps before first / after last keyframe", () => {
    expect(trackValueAt(track, -5, { x: 0, y: 0 })).toEqual({ x: 0.9, y: 0.4 });
    expect(trackValueAt(track, 5000, { x: 0, y: 0 })).toEqual({ x: 0.5, y: 0.4 });
  });

  it("lerps midpoint", () => {
    const v = trackValueAt(track, 500, { x: 0, y: 0 }) as { x: number; y: number };
    expect(v.x).toBeCloseTo(0.7);
    expect(v.y).toBe(0.4);
  });

  it("visible toggles at threshold", () => {
    const t: ObjectTrackSpec = {
      objectId: "o",
      property: "visible",
      keyframes: [
        { tMs: 0, value: false },
        { tMs: 100, value: true },
      ],
    };
    expect(trackValueAt(t, 0, true)).toBe(false);
    expect(trackValueAt(t, 100, false)).toBe(true);
  });
});

describe("EvaluatorSpec", () => {
  const spec: EvaluatorSpec = {
    cameraInitial: CAMERA_INITIAL,
    cameraSteps: [
      { center: { x: 0.6, y: 0.6 }, zoom: 1.5 },
      { center: { x: 0.4, y: 0.5 }, zoom: 1 },
    ],
    tracks: [
      {
        objectId: "boat",
        property: "position",
        keyframes: [
          { tMs: 0, value: { x: 0.9, y: 0.4 }, easing: "linear" },
          { tMs: 3000, value: { x: 0.3, y: 0.4 }, easing: "linear" },
        ],
      },
    ],
    baseObjects: {
      boat: {
        position: { x: 0.9, y: 0.4 },
        scale: 0.12,
        rotation: 0,
        opacity: 1,
        visible: true,
      },
    },
    stepDurationsMs: [1000, 2000],
    stepIds: ["s1", "s2"],
    effects: [
      { type: "MIST", intensity: 0.4, center: { x: 0.5, y: 0.5 } },
      { type: "GLOW", stepId: "s2", intensity: 0.7, center: { x: 0.3, y: 0.3 } },
      { type: "WATER_RIPPLE", stepId: "s2", durationMs: 500, intensity: 0.5, center: { x: 0.5, y: 0.5 } },
    ],
  };

  it("globalTMs sums prior durations", () => {
    expect(globalTMs(spec, 0, 0)).toBe(0);
    expect(globalTMs(spec, 0, 0.5)).toBe(500);
    expect(globalTMs(spec, 1, 0)).toBe(1000);
    expect(globalTMs(spec, 1, 1)).toBe(3000);
  });

  it("frameAt combines camera + objects", () => {
    const f = frameAt(spec, 1, 0.5, 0.5); // tMs = 2000
    expect(f.objects.boat?.position.x).toBeCloseTo(0.5);
  });

  it("frameEndAt returns final pose", () => {
    const f = frameEndAt(spec, 1);
    expect(f.camera.zoom).toBeCloseTo(1.0);
    expect(f.objects.boat?.position.x).toBeCloseTo(0.3);
  });

  it("objectsAt applies track override", () => {
    const objs = objectsAt(spec, 1500);
    expect(objs.boat?.position.x).toBeCloseTo(0.6);
  });
});

describe("effectsAt", () => {
  const spec: EvaluatorSpec = {
    cameraInitial: CAMERA_INITIAL,
    cameraSteps: [],
    tracks: [],
    baseObjects: {},
    stepDurationsMs: [1000, 2000],
    stepIds: ["s1", "s2"],
    effects: [
      { type: "MIST", intensity: 0.4, center: { x: 0.5, y: 0.5 } },
      { type: "GLOW", stepId: "s2", intensity: 0.7, center: { x: 0.3, y: 0.3 } },
      { type: "WATER_RIPPLE", stepId: "s2", durationMs: 500, intensity: 0.5, center: { x: 0.5, y: 0.5 } },
      { type: "FADE_IN", stepId: "nope", intensity: 0.5, center: { x: 0.5, y: 0.5 } },
    ],
  };

  it("ambient runs every step", () => {
    expect(effectsAt(spec, 0, 0.5).some((e) => e.type === "MIST")).toBe(true);
    expect(effectsAt(spec, 1, 0.5).some((e) => e.type === "MIST")).toBe(true);
  });

  it("step-bound only on matching stepId", () => {
    expect(effectsAt(spec, 0, 0.5).some((e) => e.type === "GLOW")).toBe(false);
    expect(effectsAt(spec, 1, 0.5).some((e) => e.type === "GLOW")).toBe(true);
  });

  it("timed effect progress = stepElapsed/durationMs", () => {
    const f = effectsAt(spec, 1, 0.25);
    const r = f.find((e) => e.type === "WATER_RIPPLE");
    expect(r?.progress).toBeCloseTo(1.0); // 500ms elapsed / 500ms duration
  });

  it("unknown stepId never emits", () => {
    for (const i of [0, 1]) {
      expect(effectsAt(spec, i, 0.5).some((e) => e.type === "FADE_IN")).toBe(false);
    }
  });
});
