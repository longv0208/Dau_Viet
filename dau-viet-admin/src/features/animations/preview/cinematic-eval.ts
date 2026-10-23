/**
 * Pure-TS port của `dau-viet-mobile/.../runtime/cinematic_state.dart` —
 * evaluator cho camera track + object keyframe tracks + scene effects.
 * PARITY CONTRACT: mọi thay đổi công thức ở đây phải cập nhật file Dart
 * (và ngược lại) — admin preview và Flutter render cùng kết quả.
 *
 * Thuần hàm (specs, tMs) → frame: deterministic seek/replay, không
 * phụ thuộc React/DOM — unit-testable.
 */

export interface Vec2 {
  x: number;
  y: number;
}

export interface CameraState {
  center: Vec2; // normalized 0..1
  zoom: number;
}

export interface ObjectVisualState {
  position: Vec2;
  scale: number;
  rotation: number;
  opacity: number;
  visible: boolean;
}

export interface KeyframeSpec {
  tMs: number;
  value: unknown; // Vec2 | number | boolean
  easing?: string; // map sang curve fn bên dưới
}

export interface ObjectTrackSpec {
  objectId: string;
  property: string;
  keyframes: KeyframeSpec[];
}

export interface SceneEffectSpec {
  type: string;
  stepId?: string;
  durationMs?: number;
  center: Vec2;
  intensity: number;
  objectId?: string;
}

export interface ActiveEffect {
  type: string;
  center: Vec2;
  intensity: number;
  objectId?: string;
  progress: number;
}

export interface CinematicFrame {
  camera: CameraState;
  objects: Record<string, ObjectVisualState>;
  effects: ActiveEffect[];
}

/* ---------- easing (khớp Curves.* của Flutter, đủ cho preview) ---------- */

export function easeValue(easing: string | undefined, t: number): number {
  const x = Math.min(1, Math.max(0, t));
  switch (easing) {
    case "linear":
      return x;
    case "easeIn":
      return x * x;
    case "easeOut":
      return 1 - (1 - x) * (1 - x);
    case "easeInOutCubic":
      return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
    case "easeInOut":
    default:
      // Curves.easeInOut ≈ cubic bezier (0.42,0,0.58,1) — xấp xỉ smoothstep.
      return x * x * (3 - 2 * x);
  }
}

/* ---------- lerp helpers ---------- */

export function lerpNum(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

export function lerpVec(a: Vec2, b: Vec2, t: number): Vec2 {
  return { x: lerpNum(a.x, b.x, t), y: lerpNum(a.y, b.y, t) };
}

function isVec2(v: unknown): v is Vec2 {
  return (
    typeof v === "object" && v !== null &&
    "x" in v && "y" in v &&
    typeof (v as Vec2).x === "number" && typeof (v as Vec2).y === "number"
  );
}

function lerpValue(a: unknown, b: unknown, t: number): unknown {
  if (isVec2(a) && isVec2(b)) return lerpVec(a, b, t);
  if (typeof a === "number" && typeof b === "number") {
    return lerpNum(a, b, t);
  }
  // bool / non-lerpable — bật tại ngưỡng 0.5 (khớp Dart _lerpValue).
  return t < 0.5 ? a : b;
}

/* ---------- camera ---------- */

export const CAMERA_INITIAL: CameraState = {
  center: { x: 0.5, y: 0.5 },
  zoom: 1,
};

export function lerpCamera(from: CameraState, to: CameraState, t: number): CameraState {
  return { center: lerpVec(from.center, to.center, t), zoom: lerpNum(from.zoom, to.zoom, t) };
}

/**
 * Camera pose tại (stepIndex, easedT, rawProgress) — steps[i] tween từ
 * pose trước (initial khi i==0) tới pose i. Giữ pose cuối khi bước không
 * khai báo. Khi `cameraEasings[idx]` có → transform `t` bằng curve đó
 * trước khi lerp (override step.easing cho riêng camera — parity Dart).
 *
 * FIX-05 — `cameraStepDurationsMs[idx]` > 0: camera hoàn thành tween
 * trong `durationMs` ms đầu của bước rồi GIỮ POSE cuối cho phần còn
 * lại — clamp tại `camDur / stepDur` của rawProgress rồi re-ease.
 */
export function cameraAt(
  initial: CameraState,
  steps: CameraState[],
  stepIndex: number,
  t: number,
  easings?: (string | null)[],
  rawProgress?: number,
  cameraStepDurationsMs?: number[],
  stepDurationsMs?: number[],
): CameraState {
  const idx = Math.min(Math.max(0, stepIndex), steps.length - 1);
  const to = steps[idx];
  if (!to) return initial;
  const from = idx === 0 ? initial : (steps[idx - 1] ?? initial);
  const override = easings?.[idx];
  const camDur = cameraStepDurationsMs?.[idx] ?? 0;
  const stepDur = stepDurationsMs?.[idx] ?? 0;
  if (camDur > 0 && stepDur > 0 && camDur < stepDur) {
    // Normalize raw progress vào phạm vi tween [0..camDur] rồi mới
    // ease — sau ngưỡng camDur, camT = curve(1) giữ pose cuối.
    const cap = camDur / stepDur;
    const raw = Math.min(1, Math.max(0, (rawProgress ?? t) / cap));
    const camT = override ? easeValue(override, raw) : raw;
    return lerpCamera(from, to, camT);
  }
  const camT = override ? easeValue(override, t) : t;
  return lerpCamera(from, to, camT);
}

/* ---------- object tracks ---------- */

function baseValue(s: ObjectVisualState, property: string): unknown {
  switch (property) {
    case "position":
      return s.position;
    case "scale":
      return s.scale;
    case "rotation":
      return s.rotation;
    case "opacity":
      return s.opacity;
    case "visible":
      return s.visible;
    default:
      return s.opacity;
  }
}

function applyValue(s: ObjectVisualState, property: string, v: unknown): ObjectVisualState {
  switch (property) {
    case "position":
      return { ...s, position: v as Vec2 };
    case "scale":
      return { ...s, scale: v as number };
    case "rotation":
      return { ...s, rotation: v as number };
    case "opacity":
      return { ...s, opacity: v as number };
    case "visible":
      return { ...s, visible: v as boolean };
    default:
      return s;
  }
}

/** Giá trị track tại tMs — clamp ngoài biên, nội suy giữa 2 key bao quanh. */
export function trackValueAt(track: ObjectTrackSpec, tMs: number, base: unknown): unknown {
  const ks = track.keyframes;
  const first = ks[0];
  const last = ks[ks.length - 1];
  if (!first || !last) return base;
  if (tMs <= first.tMs) return first.value;
  if (tMs >= last.tMs) return last.value;
  for (let i = 0; i < ks.length - 1; i++) {
    const a = ks[i];
    const b = ks[i + 1];
    if (a && b && tMs >= a.tMs && tMs <= b.tMs) {
      const span = b.tMs - a.tMs;
      const raw = span <= 0 ? 1 : (tMs - a.tMs) / span;
      const t = easeValue(b.easing, raw);
      return lerpValue(a.value, b.value, t);
    }
  }
  return last.value;
}

/* ---------- evaluator ---------- */

export interface EvaluatorSpec {
  cameraInitial: CameraState;
  cameraSteps: CameraState[];
  /** P1 §5 — camera.steps[].easing (whitelist) override step.easing
   * cho camera tween — parity Dart `cameraEasings`. Index-aligned với
   * cameraSteps; null/missing = dùng easedT của caller. */
  cameraEasings?: (string | null)[];
  /** FIX-05 — camera.steps[].durationMs (index-aligned). >0 → camera
   * tween hoàn thành trong durationMs đầu bước rồi GIỮ POSE cuối cho
   * phần còn lại (hold-pose); 0/vắng = camera chạy cả bước như cũ. */
  cameraStepDurationsMs?: number[];
  tracks: ObjectTrackSpec[];
  baseObjects: Record<string, ObjectVisualState>;
  stepDurationsMs: number[];
  stepIds: string[];
  effects: SceneEffectSpec[];
}

/** tMs toàn cục = tổng duration các bước trước + progress trong bước. */
export function globalTMs(spec: EvaluatorSpec, stepIndex: number, progress: number): number {
  let acc = 0;
  for (let i = 0; i < stepIndex && i < spec.stepDurationsMs.length; i++) {
    acc += spec.stepDurationsMs[i] ?? 0;
  }
  const cur = spec.stepDurationsMs[stepIndex];
  if (cur !== undefined) {
    acc += Math.round(cur * Math.min(1, Math.max(0, progress)));
  }
  return acc;
}

export function objectsAt(spec: EvaluatorSpec, tMs: number): Record<string, ObjectVisualState> {
  const out: Record<string, ObjectVisualState> = { ...spec.baseObjects };
  for (const track of spec.tracks) {
    const base = out[track.objectId];
    if (!base) continue;
    const v = trackValueAt(track, tMs, baseValue(base, track.property));
    out[track.objectId] = applyValue(base, track.property, v);
  }
  return out;
}

/** Effects active tại (stepIndex, rawProgress) — lọc theo stepId, ambient
 * (stepId rỗng) chạy mọi step. Progress = rawProgress khi durationMs<=0,
 * else stepElapsed/durationMs. */
export function effectsAt(spec: EvaluatorSpec, stepIndex: number, rawProgress: number): ActiveEffect[] {
  const sid = stepIndex < spec.stepIds.length ? spec.stepIds[stepIndex] : undefined;
  const dur = spec.stepDurationsMs[stepIndex] ?? 0;
  const out: ActiveEffect[] = [];
  for (const e of spec.effects) {
    const isAmbient = !e.stepId;
    if (!isAmbient && e.stepId !== sid) continue;
    let p = rawProgress;
    const eDur = e.durationMs ?? 0;
    if (eDur > 0 && dur > 0) {
      p = Math.min(1, Math.max(0, (rawProgress * dur) / eDur));
    }
    out.push({
      type: e.type,
      center: e.center,
      intensity: e.intensity,
      objectId: e.objectId,
      progress: p,
    });
  }
  return out;
}

export function frameAt(
  spec: EvaluatorSpec,
  stepIndex: number,
  easedT: number,
  rawProgress: number,
): CinematicFrame {
  const tMs = globalTMs(spec, stepIndex, rawProgress);
  return {
    camera: cameraAt(
      spec.cameraInitial, spec.cameraSteps, stepIndex, easedT,
      spec.cameraEasings, rawProgress,
      spec.cameraStepDurationsMs, spec.stepDurationsMs,
    ),
    objects: objectsAt(spec, tMs),
    effects: effectsAt(spec, stepIndex, rawProgress),
  };
}

/** Frame CUỐI bước — reduced-motion/skip nhảy thẳng đây. */
export function frameEndAt(spec: EvaluatorSpec, stepIndex: number): CinematicFrame {
  return frameAt(spec, stepIndex, 1, 1);
}

/* ---------- scene-state interpolation (PARITY: SceneTransition.applyFrom) ---------- */

/**
 * Trạng thái painter hiệu dụng tại progress `t` trong bước — parity với
 * `SceneTransition.applyFrom(painter, from, t)` của Flutter:
 *
 *  - RIVER_TIDE (`RiverSceneState`): lerp `waterLevel`, `boatProgress`,
 *    `decoyProgress`, `counterattackProgress` từ snapshot `from`;
 *    `obstructed`/`highlightStakes`/`showSequenceSummary` áp NGAY từ
 *    target (Dart gán boolean thẳng, không lerp).
 *  - JOURNEY_MAP (`MapSceneState`): lerp từng entry của `markerVisibility`
 *    và `routeProgress` trên union keys (key vắng = 0 — fade-out có chủ
 *    đích); `markerHighlight` + `focusedLocationId` áp NGAY từ target.
 *
 * `from` phải là snapshot ĐÓNG BĂNG lúc tween bắt đầu (end-state merge
 * của bước trước) — không phải trạng thái frame trước, để kết quả tại
 * t độc lập số frame đã render (giống `_tweenFrom` trong player).
 * Bước không khai báo targetState → trả `base` (painter giữ nguyên).
 * `t = 1` vẫn trả state đích đã nội suy xong (default field tính ra
 * giá trị cuối, khớp `applyFrom(t=1)` trên typed target).
 *
 * Key lạ (không thuộc whitelist renderer) lọt sang `out` ở trạng thái
 * đích như merge cũ — bảo toàn tương thích field mở rộng tương lai.
 */
export function lerpSceneState(
  rendererCode: string | undefined,
  base: Record<string, unknown>,
  from: Record<string, unknown>,
  to: Record<string, unknown>,
  t: number,
): Record<string, unknown> {
  // Step không khai báo targetState → `_target` trả null → player không
  // tween, painter GIỮ NGUYÊN trạng thái hiện tại (không reset default).
  if (Object.keys(to).length === 0) return { ...base };
  const out = mergeSceneState(base, to);

  if (rendererCode === "RIVER_TIDE") {
    // Dart `_target` decode: key vắng → default typed-state
    // (waterLevel 0.3, các progress 0) — KHÔNG giữ giá trị cũ. Và
    // `applyFrom` lerp `from[key] ?? painter[key]`: painter-current ≈
    // `base` (end-state bước trước) nếu `from` thiếu key.
    for (const [key, def] of [
      ["waterLevel", 0.3],
      ["boatProgress", 0],
      ["decoyProgress", 0],
      ["counterattackProgress", 0],
    ] as const) {
      const a = numOf(from[key], numOf(base[key], def)) ?? def;
      const b = numOf(to[key], def) ?? def;
      out[key] = lerpNum(a, b, t);
    }
  } else if (rendererCode === "JOURNEY_MAP") {
    out.markerVisibility = lerpIdMap(from.markerVisibility, to.markerVisibility, t);
    out.routeProgress = lerpIdMap(from.routeProgress, to.routeProgress, t);
  }
  return out;
}

/**
 * Merge end-state của một step lên `base` — deep-merge map con
 * (markerVisibility/routeProgress) rồi overwrite scalar. Dùng để chụp
 * snapshot `from` cho bước kế tiếp và cho trạng thái "đứng yên"
 * (paused/không playing) — tương đương `_applyCurrent(1)`.
 */
export function mergeSceneState(
  base: Record<string, unknown>,
  target: Record<string, unknown> | undefined,
): Record<string, unknown> {
  const merged: Record<string, unknown> = { ...base };
  if (!target) return merged;
  for (const [k, v] of Object.entries(target)) {
    const prev = merged[k];
    if (
      v !== null && typeof v === "object" && !Array.isArray(v) &&
      prev !== null && typeof prev === "object" && !Array.isArray(prev)
    ) {
      merged[k] = { ...(prev as Record<string, unknown>), ...(v as Record<string, unknown>) };
    } else {
      merged[k] = v;
    }
  }
  return merged;
}

function numOf(v: unknown, fallback?: number): number | undefined {
  if (typeof v === "number") return v;
  return fallback;
}

/** Parity `MapSceneState._lerpIdMap` — union keys, vắng = 0. */
function lerpIdMap(
  from: unknown,
  to: unknown,
  t: number,
): Record<string, number> {
  const f = asNumMap(from);
  const g = asNumMap(to);
  const out: Record<string, number> = {};
  for (const k of new Set([...Object.keys(f), ...Object.keys(g)])) {
    out[k] = lerpNum(f[k] ?? 0, g[k] ?? 0, t);
  }
  return out;
}

function asNumMap(v: unknown): Record<string, number> {
  if (v === null || typeof v !== "object" || Array.isArray(v)) return {};
  const out: Record<string, number> = {};
  for (const [k, val] of Object.entries(v as Record<string, unknown>)) {
    if (typeof val === "number") out[k] = val;
  }
  return out;
}
