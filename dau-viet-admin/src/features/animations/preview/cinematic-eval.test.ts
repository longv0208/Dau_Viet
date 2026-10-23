import { describe, expect, it } from "vitest";

import {
  CAMERA_INITIAL,
  cameraAt,
  effectsAt,
  frameAt,
  frameEndAt,
  globalTMs,
  lerpCamera,
  lerpSceneState,
  mergeSceneState,
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

  it("cameraAt with cameraEasings override applies per-step curve", () => {
    const steps = [
      { center: { x: 1.0, y: 0.5 }, zoom: 1.0 }, // đích step 0
      { center: { x: 0.0, y: 0.5 }, zoom: 2.0 }, // đích step 1
    ];
    // Step 0 easing = "linear" → camT = raw (0.5 → 0.5).
    const eased = cameraAt(CAMERA_INITIAL, steps, 0, 0.5, ["linear"]);
    expect(eased.center.x).toBeCloseTo(0.75);
    // Step 0 easing = "easeIn" (x²) → camT = 0.25 → chậm hơn linear.
    const easeIn = cameraAt(CAMERA_INITIAL, steps, 0, 0.5, ["easeIn"]);
    expect(easeIn.center.x).toBeCloseTo(0.625);
    // Không khai báo → giữ nguyên easedT caller truyền (step.easing).
    const fallback = cameraAt(CAMERA_INITIAL, steps, 0, 0.5);
    expect(fallback.center.x).toBeCloseTo(0.75);
  });

  /* ---------- FIX-P1 §3 — camera easing override semantics ---------- */

  // Helper: CAMERA_INITIAL.x = 0.5 → đích x = 1.0. Lerp range = 0.5,
  // nên expected.x = 0.5 + 0.5*camT. `xOf(camT)` đọc rõ contract.
  const camSteps = [
    { center: { x: 1.0, y: 0.5 }, zoom: 2.0 },
    { center: { x: 0.0, y: 0.5 }, zoom: 1.0 },
  ];
  const xOf = (camT: number) => 0.5 + 0.5 * camT;

  it("camera.easing override nội suy trên RAW progress, không double-ease", () => {
    // step.easing=easeOut (caller truyền easedT = easeOut(0.5)=0.75),
    // camera.easing="linear" → camera dùng RAW=0.5 → camT=0.5.
    // (Bug cũ: easeValue(override, easedT) → double easing → sai pose.)
    const f = cameraAt(
      CAMERA_INITIAL, camSteps, 0,
      /* easedT (step easeOut @0.5) */ 0.75,
      /* cameraEasings */ ["linear"],
      /* rawProgress */ 0.5,
    );
    // camT = raw = 0.5 → x = 0.5 + 0.5*0.5 = 0.75 (không phải easedT 0.75→x≈0.875).
    expect(f.center.x).toBeCloseTo(xOf(0.5), 5);
  });

  it("step linear + camera easeIn → camera easeIn applied once on raw", () => {
    // step.easing=linear → easedT=raw. camera.easing=easeIn → camT=easeIn(raw)=raw².
    for (const raw of [0, 0.25, 0.5, 0.75, 1]) {
      const f = cameraAt(
        CAMERA_INITIAL, camSteps, 0, raw, ["easeIn"], raw,
      );
      expect(f.center.x).toBeCloseTo(xOf(raw * raw), 5);
    }
  });

  it("step easeOut + camera linear → camera linear on raw (không phải easeOut)", () => {
    // easedT = easeOut(raw) = 1-(1-raw)². camera linear → camT = raw.
    for (const raw of [0, 0.25, 0.5, 0.75, 1]) {
      const easedT = 1 - (1 - raw) * (1 - raw);
      const f = cameraAt(
        CAMERA_INITIAL, camSteps, 0, easedT, ["linear"], raw,
      );
      expect(f.center.x).toBeCloseTo(xOf(raw), 5); // raw, không easedT
    }
  });

  it("step easeInOut + camera easeOut → camera easeOut on raw", () => {
    // easedT = smoothstep(raw); camera easeOut → camT = easeOut(raw).
    const easeOut = (x: number) => 1 - (1 - x) * (1 - x);
    for (const raw of [0, 0.25, 0.5, 0.75, 1]) {
      const easedT = raw * raw * (3 - 2 * raw); // smoothstep
      const f = cameraAt(
        CAMERA_INITIAL, camSteps, 0, easedT, ["easeOut"], raw,
      );
      expect(f.center.x).toBeCloseTo(xOf(easeOut(raw)), 5);
    }
  });

  it("camera.durationMs < step.durationMs + camera.easing → ease once trong window rồi hold", () => {
    // step=2000ms, camera=500ms → cap=0.25. camera.easing=easeIn.
    const [camDur, stepDur] = [[500], [2000]];
    // raw 0.125 (nửa window) → inTween=0.5 → easeIn(0.5)=0.25 → x=0.5+0.5*0.25.
    const mid = cameraAt(
      CAMERA_INITIAL, camSteps, 0,
      /* easedT (step linear @0.125) */ 0.125,
      ["easeIn"], 0.125, camDur, stepDur,
    );
    expect(mid.center.x).toBeCloseTo(xOf(0.25), 5);
    // raw 0.5 (sau cap) → inTween=1 → easeIn(1)=1 → hold pose cuối x=1.0.
    const held = cameraAt(
      CAMERA_INITIAL, camSteps, 0, 0.5, ["easeIn"], 0.5, camDur, stepDur,
    );
    expect(held.center.x).toBeCloseTo(1.0);
    // raw 0.9 → vẫn hold.
    const held2 = cameraAt(
      CAMERA_INITIAL, camSteps, 0, 0.9, ["easeIn"], 0.9, camDur, stepDur,
    );
    expect(held2.center.x).toBeCloseTo(1.0);
  });

  it("không camera.easing → camera dùng step.easing (easedT)", () => {
    // cameraEasings = [null] → camT = easedT caller truyền.
    const f = cameraAt(
      CAMERA_INITIAL, camSteps, 0,
      /* easedT = easeInOut(0.5) = 0.5 */ 0.5,
      [null], 0.5,
    );
    expect(f.center.x).toBeCloseTo(xOf(0.5), 5);
  });

  /* ---------- FIX-P1 §3 — camDur + no override → step.easing ---------- */

  it("camDur<stepDur KHÔNG camera.easing → dùng STEP.easing, không linear", () => {
    // step.easing=easeIn (x²), camDur=500/stepDur=2000 → cap=0.25.
    // raw=0.125 → inTween=0.5 → stepEase(0.5)=0.25 → camT=0.25 → x=0.5+0.5*0.25=0.625.
    // (Linear cũ: camT=0.5 → x=0.75 — KHÁC. Contract mới = step ease 1 lần.)
    const f = cameraAt(
      CAMERA_INITIAL, camSteps, 0,
      /* easedT (easeIn(0.125)≈0.0156) */ 0.125 * 0.125,
      /* easings */ [null],
      /* raw */ 0.125, [500], [2000],
      /* stepEasing */ "easeIn",
    );
    expect(f.center.x).toBeCloseTo(xOf(0.25), 5); // easeIn(0.5)=0.25

    // raw=0.25 (cuối window) → inTween=1 → easeIn(1)=1 → hold x=1.0.
    const held = cameraAt(
      CAMERA_INITIAL, camSteps, 0, 0.0625, [null], 0.25,
      [500], [2000], "easeIn",
    );
    expect(held.center.x).toBeCloseTo(1.0);
  });

  it("camDur<stepDur + step easeOut no override → easeOut(inTween)", () => {
    const easeOut = (x: number) => 1 - (1 - x) * (1 - x);
    for (const raw of [0, 0.125, 0.25]) {
      const inTween = Math.min(1, raw / 0.25);
      const f = cameraAt(
        CAMERA_INITIAL, camSteps, 0,
        /* easedT=stepEaseOut(raw) */ easeOut(raw),
        [null], raw, [500], [2000], "easeOut",
      );
      expect(f.center.x).toBeCloseTo(xOf(easeOut(inTween)), 5);
    }
  });

  it("camDur==stepDur → tween cả step như không camDur", () => {
    // camDur=2000==stepDur → nhánh else: camT = easedT (không override).
    const f = cameraAt(
      CAMERA_INITIAL, camSteps, 0, 0.5, [null], 0.5,
      [2000], [2000], "easeIn",
    );
    expect(f.center.x).toBeCloseTo(xOf(0.5), 5);
  });

  it("cameraAt with cameraStepDurationsMs clamps tween to window", () => {
    const steps = [
      { center: { x: 1.0, y: 0.5 }, zoom: 2.0 }, // đích step 0
      { center: { x: 0.0, y: 0.5 }, zoom: 1.0 },
    ];
    // camera.steps[0].durationMs = 500 trong step 2000ms → cap = 0.25.
    // rawProgress 0.125 (nửa cửa sổ) → camT = 0.5 → giữa tween.
    const mid = cameraAt(
      CAMERA_INITIAL, steps, 0, 0.5, undefined, 0.125, [500], [2000],
    );
    expect(mid.center.x).toBeCloseTo(0.75);
    expect(mid.zoom).toBeCloseTo(1.5);
    // rawProgress 0.5 (sau cap 0.25) → camT = 1 → giữ pose cuối.
    const held = cameraAt(
      CAMERA_INITIAL, steps, 0, 1.0, undefined, 0.5, [500], [2000],
    );
    expect(held.center.x).toBeCloseTo(1.0);
    expect(held.zoom).toBeCloseTo(2.0);
    // Không khai báo durationMs → camera chạy cả bước như cũ.
    const full = cameraAt(
      CAMERA_INITIAL, steps, 0, 0.5, undefined, 0.5, [0], [2000],
    );
    expect(full.center.x).toBeCloseTo(0.75);
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

/* ---------- FIX-02 — lerpSceneState parity với SceneTransition.applyFrom ---------- */

describe("lerpSceneState (RIVER_TIDE)", () => {
  const base = { waterLevel: 0.3, boatProgress: 0 };
  const from = { waterLevel: 0.3, boatProgress: 0.2, decoyProgress: 0 };
  const to = { waterLevel: 0.9, boatProgress: 1, obstructed: true, highlightStakes: true };

  it.each([0, 0.25, 0.5, 0.75, 1])(
    "lerps numeric fields at progress %s, flags apply at target",
    (t) => {
      const s = lerpSceneState("RIVER_TIDE", base, from, to, t);
      expect(s.waterLevel as number).toBeCloseTo(0.3 + (0.9 - 0.3) * t);
      expect(s.boatProgress as number).toBeCloseTo(0.2 + (1 - 0.2) * t);
      // Boolean cờ áp NGAY từ target (Dart gán thẳng, không lerp).
      expect(s.obstructed).toBe(true);
      expect(s.highlightStakes).toBe(true);
    },
  );

  it("missing target field decodes to typed default (0), not stale merge", () => {
    // Dart `_target`: vắng `decoyProgress` → 0, không giữ end-state trước.
    const s = lerpSceneState(
      "RIVER_TIDE",
      base,
      { decoyProgress: 0.8 },
      { boatProgress: 0.5 },
      0.5,
    );
    expect(s.decoyProgress as number).toBeCloseTo(0.4); // 0.8 → 0 midpoint
  });

  it("mid-step change lerps from previous end-state", () => {
    // Step trước kết ở boat 0.4 → bước này target 0.8, t=0.5 → 0.6.
    const s = lerpSceneState(
      "RIVER_TIDE",
      base,
      { boatProgress: 0.4 },
      { boatProgress: 0.8 },
      0.5,
    );
    expect(s.boatProgress as number).toBeCloseTo(0.6);
  });
});

describe("lerpSceneState (JOURNEY_MAP)", () => {
  const base: Record<string, unknown> = { markerVisibility: { a: 1 } };

  it("lerps markerVisibility/routeProgress on union keys", () => {
    const s = lerpSceneState(
      "JOURNEY_MAP",
      base,
      { markerVisibility: { a: 1, b: 0 }, routeProgress: { r1: 0.2 } },
      { markerVisibility: { a: 0, b: 1 }, routeProgress: { r1: 1, r2: 0.5 } },
      0.5,
    );
    const vis = s.markerVisibility as Record<string, number>;
    expect(vis.a).toBeCloseTo(0.5);
    expect(vis.b).toBeCloseTo(0.5);
    const rp = s.routeProgress as Record<string, number>;
    expect(rp.r1).toBeCloseTo(0.6);
    expect(rp.r2).toBeCloseTo(0.25); // 0 → 0.5
  });

  it("focusedLocationId + markerHighlight apply at target immediately", () => {
    const s = lerpSceneState(
      "JOURNEY_MAP",
      base,
      {},
      { focusedLocationId: "x", markerHighlight: ["a", "b"] },
      0.1,
    );
    expect(s.focusedLocationId).toBe("x");
    expect(s.markerHighlight).toEqual(["a", "b"]);
  });

  it("t=1 settles at decoded target (missing map key fades to 0)", () => {
    // targetState CÓ field khác nhưng vắng markerVisibility → Dart decode
    // markerVisibility = {} → union-key lerp kéo 'a' về 0.
    const s = lerpSceneState(
      "JOURNEY_MAP",
      base,
      { markerVisibility: { a: 1 } },
      { focusedLocationId: "b" },
      1,
    );
    expect(s.markerVisibility).toEqual({ a: 0 });
    expect(s.focusedLocationId).toBe("b");
  });

  it("empty targetState keeps prior state (player does not tween)", () => {
    const s = lerpSceneState("JOURNEY_MAP", base, base, {}, 0.5);
    expect(s.markerVisibility).toEqual({ a: 1 });
  });
});

describe("mergeSceneState", () => {
  it("deep-merges nested maps, overwrites scalars", () => {
    const m = mergeSceneState(
      { markerVisibility: { a: 1 }, waterLevel: 0.3 },
      { markerVisibility: { b: 0.5 }, waterLevel: 0.9 },
    );
    expect(m.markerVisibility).toEqual({ a: 1, b: 0.5 });
    expect(m.waterLevel).toBe(0.9);
  });
});
