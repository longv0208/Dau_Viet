"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Pause, Play, RotateCcw, SkipBack, SkipForward } from "lucide-react";

import { Button } from "@/components/ui/button";
import { useAssetObjectUrl } from "@/features/assets/use-asset-object-url";

import type { AnimationManifest, ManifestStep } from "../animation-types";
import {
  CAMERA_INITIAL,
  easeValue,
  frameAt,
  lerpSceneState,
  type EvaluatorSpec,
  type SceneEffectSpec,
} from "../preview/cinematic-eval";

/** Ảnh nền preview — tải qua BFF có auth, một lần (không per-frame). */
function ManifestImage({ assetId, alt, className }: { assetId: string; alt: string; className?: string }) {
  const { src } = useAssetObjectUrl(`/api/v1/admin/assets/${assetId}/content`);
  if (!src) return null;
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={src} alt={alt} className={className} />;
}

/**
 * Playback state machine tối thiểu (FIX-P1):
 *   idle → playing → paused → playing → finished → playing
 * - idle:    trạng thái tĩnh (progress=1 của bước hiện tại), chưa phát.
 * - playing: rAF đang tick, progress chạy theo wall-clock.
 * - paused:  giữ progress tại thời điểm pause, không rAF.
 * - finished:đã chạy hết step cuối, giữ frame cuối; Play → replay từ 0.
 *
 * `progress` nằm ngoài status vì preview tĩnh dùng progress=1 (end-state
 * của bước) còn playing dùng progress thật; `playbackElapsed` giữ tích
 * lũy ms trong step để Resume không chạy bù.
 */
type PlaybackStatus = "idle" | "playing" | "paused" | "finished";

/**
 * Preview tương tác thật: đọc manifest.steps[].targetState và vẽ lại
 * hình học cảnh bằng SVG (rect/circle/path) — đơn giản nhưng phản ánh
 * đúng dữ liệu manifest, không phải stub. Hỗ trợ phát tự động theo
 * durationMs + tương tác WATER_LEVEL_CONTROL / TAP_TO_EXPLORE.
 */
export function ScenePreview({ manifest }: { manifest: AnimationManifest }) {
  const steps = useMemo(() => manifest.steps ?? [], [manifest.steps]);
  const [index, setIndex] = useState(0);
  const [status, setStatus] = useState<PlaybackStatus>("idle");
  const [waterOverride, setWaterOverride] = useState<number | null>(null);
  const [tappedId, setTappedId] = useState<string | null>(null);
  const [progress, setProgress] = useState(1);

  const rafRef = useRef<number | null>(null);
  // Timestamp bắt đầu đoạn playing hiện tại của step (đã rebase sau pause).
  const stepStartRef = useRef(0);
  // Tổng ms đã elapsed trong step TRƯỚC khi pause — Resume: start =
  // now - elapsed → không chạy bù thời gian đứng.
  const elapsedBeforePauseRef = useRef(0);

  const indexRef = useRef(index);
  const statusRef = useRef<PlaybackStatus>(status);
  const stepsRef = useRef(steps);
  const progressRef = useRef(progress);

  const clampedIndex = Math.min(index, Math.max(0, steps.length - 1));
  const step: ManifestStep | undefined = steps[clampedIndex];
  const playing = status === "playing";

  // Đồng bộ refs mỗi render — tick đọc state mới nhất, không re-register.
  useEffect(() => {
    indexRef.current = clampedIndex;
    statusRef.current = status;
    stepsRef.current = steps;
    progressRef.current = progress;
  });

  /* ---------- rAF loop — MỘT vòng duy nhất, sống/chết theo `status`.
     tick: đọc duration/index từ ref → tính p từ (now - stepStart);
     p>=1 → next step (rebase stepStart) hoặc finished. ---------- */
  useEffect(() => {
    if (status !== "playing") return;
    rafRef.current = requestAnimationFrame(function tick(now: number) {
      const list = stepsRef.current;
      const i = indexRef.current;
      if (list.length === 0 || statusRef.current !== "playing") {
        rafRef.current = null;
        return;
      }
      const duration = Math.max(200, list[Math.min(i, list.length - 1)]?.durationMs ?? 4000);
      const elapsed = now - stepStartRef.current;
      const p = Math.min(1, elapsed / duration);
      setProgress(p);
      if (p >= 1) {
        if (i < list.length - 1) {
          indexRef.current = i + 1;
          setIndex(i + 1);
          setProgress(0);
          elapsedBeforePauseRef.current = 0;
          stepStartRef.current = now;
          rafRef.current = requestAnimationFrame(tick);
        } else {
          // Hết step cuối → finished, giữ frame cuối (progress vừa set =1).
          statusRef.current = "finished";
          setStatus("finished");
          elapsedBeforePauseRef.current = 0;
          rafRef.current = null;
        }
        return;
      }
      rafRef.current = requestAnimationFrame(tick);
    });
    return () => {
      if (rafRef.current != null) cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    };
  }, [status]);

  /* ---------- navigation ---------- */
  const go = (i: number) => {
    const next = Math.max(0, Math.min(i, steps.length - 1));
    indexRef.current = next;
    setIndex(next);
    // Đang phát → step mới tween từ đầu; idle/paused → giữ end-state tĩnh
    // (paused giữ progress hiện tại khi đổi step — deterministic).
    if (status === "playing") {
      setProgress(0);
      elapsedBeforePauseRef.current = 0;
      stepStartRef.current = performance.now();
    } else if (status === "idle" || status === "finished") {
      setProgress(1);
      elapsedBeforePauseRef.current = 0;
    }
    setWaterOverride(null);
  };

  /* ---------- transport ---------- */
  const play = () => {
    if (steps.length === 0) return;
    if (status === "finished" || (status === "idle" && index >= steps.length - 1)) {
      // Replay: step 0, progress 0, reset transient (water/marker).
      indexRef.current = 0;
      setIndex(0);
      setProgress(0);
      elapsedBeforePauseRef.current = 0;
      stepStartRef.current = performance.now();
      setWaterOverride(null);
      setTappedId(null);
    } else if (status === "paused") {
      // Resume: rebase start = now - elapsed trước pause → không chạy bù.
      stepStartRef.current = performance.now() - elapsedBeforePauseRef.current;
    } else {
      // idle: preview đang hiển thị end-state (progress=1) → reset về 0
      // rồi phát thật; timestamp chốt ngay lúc bấm Play.
      setProgress(0);
      elapsedBeforePauseRef.current = 0;
      stepStartRef.current = performance.now();
    }
    statusRef.current = "playing";
    setStatus("playing");
  };

  const pause = () => {
    // stepStart đã rebase sau mỗi resume → elapsed trong step = now − start.
    // Ghi lại để Resume rebase tiếp; progress giữ nguyên frame, không snap.
    elapsedBeforePauseRef.current = performance.now() - stepStartRef.current;
    statusRef.current = "paused";
    setStatus("paused");
  };

  const togglePlay = () => {
    if (status === "playing") pause();
    else play();
  };

  /* ---------- scene state ---------- */
  // FIX-02 — trạng thái hiệu lực NỘI SUY theo eased progress (parity
  // `SceneTransition.applyFrom` của Flutter), không còn snap thẳng về
  // targetState: `from` = end-state bước trước (initialState khi bước
  // đầu), `to` = raw targetState bước hiện tại. Bước không targetState
  // giữ nguyên state của bước trước.
  // rawProgress cho scene-state + cinematic: playing → progress thật;
  // paused → GIỮ frame đã đóng băng lúc pause (progress cũ, không snap
  // về 1); idle/finished → end-state tĩnh (progress=1).
  const rawFrame = (status === "playing" || status === "paused") ? progress : 1;

  const state = useMemo(() => {
    const base: Record<string, unknown> = { ...(manifest.initialState ?? {}) };
    let from = base;
    for (let i = 0; i < clampedIndex; i++) {
      const t = steps[i]?.targetState;
      from = t ? lerpSceneState(manifest.rendererCode, base, from, t, 1) : from;
    }
    const target = step?.targetState ?? {};
    const easedT = easeValue(step?.easing, rawFrame);
    const merged = lerpSceneState(manifest.rendererCode, base, from, target, easedT);
    if (waterOverride != null) merged.waterLevel = waterOverride;
    return merged;
  }, [manifest.initialState, manifest.rendererCode, steps, clampedIndex, step, rawFrame, waterOverride]);

  const allowWater = step?.allowedInteractions?.includes("WATER_LEVEL_CONTROL");
  const allowTap = step?.allowedInteractions?.includes("TAP_TO_EXPLORE");

  const aspect = manifest.canvas?.aspectRatio ?? 1.6;
  const assets = useMemo(() => manifest.assets ?? [], [manifest.assets]);
  const objects = useMemo(() => manifest.objects ?? [], [manifest.objects]);

  const bgAssetId = manifest.map?.backgroundAssetId ??
    assets.find((a) => a.role === "BACKGROUND")?.assetId;
  const PROCEDURAL_TYPES = useMemo(() => new Set([
    "STAKE", "BOAT", "DECOY", "MARKER", "LABEL", "ROUTE", "LOCATION",
    "WATER", "TEXT",
  ]), []);
  const objectLayers = useMemo(() => {
    const byKey = new Map(assets.map((a) => [a.id, a]));
    return objects
      .filter((o) => {
        if (o.visible === false) return false;
        const ref = o.assetRef ? byKey.get(o.assetRef) : null;
        if (ref == null) return PROCEDURAL_TYPES.has(o.type ?? "");
        return ref.role === "OBJECT";
      })
      .map((o) => ({
        object: o,
        ref: o.assetRef ? byKey.get(o.assetRef) : undefined,
      }))
      .sort((a, b) => (a.object.layer ?? 0) - (b.object.layer ?? 0));
  }, [assets, objects, PROCEDURAL_TYPES]);

  /* ---------- v2 cinematic spec ---------- */
  const cinematicSpec = useMemo<EvaluatorSpec | null>(() => {
    const cam = manifest.camera;
    const tracks = manifest.tracks ?? [];
    const effects = manifest.effects ?? [];
    const hasV2 = cam || tracks.length > 0 || effects.length > 0;
    if (!hasV2) return null;
    return {
      cameraInitial: cam
        ? { center: { x: cam.initial.x, y: cam.initial.y }, zoom: cam.initial.zoom }
        : CAMERA_INITIAL,
      cameraSteps: (cam?.steps ?? []).map((s) => ({
        center: { x: s.target.x, y: s.target.y },
        zoom: s.target.zoom,
      })),
      cameraEasings: (cam?.steps ?? []).map((s) => s.easing ?? null),
      cameraStepDurationsMs: (cam?.steps ?? []).map((s) => s.durationMs ?? 0),
      tracks: tracks.map((t) => ({
        objectId: t.objectId,
        property: t.property,
        keyframes: t.keyframes.map((k) => ({
          tMs: k.tMs,
          value: k.value,
          easing: k.easing,
        })),
      })),
      baseObjects: Object.fromEntries(
        objects.map((o) => [
          o.id,
          {
            position: { x: o.position?.x ?? 0.5, y: o.position?.y ?? 0.5 },
            scale: o.scale ?? 0.12,
            rotation: o.rotation ?? 0,
            opacity: o.visible === false ? 0 : 1,
            visible: o.visible !== false,
          },
        ]),
      ),
      stepDurationsMs: steps.map((s) => s.durationMs ?? 4000),
      stepIds: steps.map((s) => s.id),
      effects: effects.map((e): SceneEffectSpec => ({
        type: e.type,
        stepId: e.stepId,
        durationMs: e.durationMs,
        center: {
          x: (e.params?.x as number) ?? 0.5,
          y: (e.params?.y as number) ?? 0.5,
        },
        intensity: (e.params?.intensity as number) ?? 0.5,
        objectId: e.params?.objectId as string | undefined,
      })),
    };
  }, [manifest.camera, manifest.tracks, manifest.effects, objects, steps]);

  const cinematicFrame = useMemo(() => {
    if (!cinematicSpec) return null;
    const easedT = easeValue(step?.easing, rawFrame);
    return frameAt(cinematicSpec, clampedIndex, easedT, rawFrame);
  }, [cinematicSpec, clampedIndex, rawFrame, step?.easing]);

  const cameraStyle = useMemo(() => {
    const cam = cinematicFrame?.camera;
    if (!cam) return undefined;
    const dx = (0.5 - cam.center.x) * 100;
    const dy = (0.5 - cam.center.y) * 100;
    return {
      transform:
        `scale(${cam.zoom}) ` +
        `translate(${dx.toFixed(3)}%, ${dy.toFixed(3)}%)`,
    } as const;
  }, [cinematicFrame]);

  const activeEffects = cinematicFrame?.effects ?? [];
  const audioForStep = (manifest.audio ?? []).filter((c) => c.stepId === step?.id);
  const env = manifest.environment;

  return (
    <div className="flex flex-col gap-3" data-testid="scene-preview">
      <div
        className="relative overflow-hidden rounded-lg border border-border bg-[#f3ead3]"
        style={{ aspectRatio: String(aspect) }}
      >
        <div className="absolute inset-0" style={cameraStyle} data-testid="camera-layer">
          {bgAssetId && (
            <ManifestImage
              assetId={bgAssetId}
              alt={assets.find((a) => a.assetId === bgAssetId)?.assetId ?? "Nền minh họa"}
              className="absolute inset-0 h-full w-full object-cover opacity-45"
            />
          )}
          {(env?.glow ?? 0) > 0 && (
            <div
              className="pointer-events-none absolute inset-0"
              style={{
                background: `radial-gradient(circle at 50% 42%, rgba(232,184,109,${(env!.glow! * 0.5).toFixed(2)}) 0%, transparent 55%)`,
              }}
            />
          )}
          <div className="absolute inset-0">
            {manifest.rendererCode === "RIVER_TIDE" ? (
              <RiverPreview manifest={manifest} state={state} />
            ) : (
              <MapPreview
                manifest={manifest}
                state={state}
                interactive={!!allowTap}
                tappedId={tappedId}
                onTap={setTappedId}
              />
            )}
          </div>
          {(env?.mist ?? 0) > 0 && (
            <div
              className="pointer-events-none absolute inset-0"
              style={{
                background: `linear-gradient(to bottom, rgba(243,234,211,${(env!.mist! * 0.85).toFixed(2)}) 0%, transparent 62%, rgba(243,234,211,${(env!.mist! * 0.5).toFixed(2)}) 100%)`,
              }}
            />
          )}
          {objectLayers.map(({ object, ref }) => {
            const vs = cinematicFrame?.objects[object.id];
            const pos = vs?.position ?? { x: object.position?.x ?? 0.5, y: object.position?.y ?? 0.5 };
            const scale = vs?.scale ?? object.scale ?? 0.12;
            const rotation = vs?.rotation ?? object.rotation ?? 0;
            const opacity = vs?.opacity ?? (object.visible === false ? 0 : 1);
            const visible = vs?.visible ?? object.visible !== false;
            if (!visible || opacity <= 0) return null;
            const w = `${Math.max(24, Math.round(scale * 640))}px`;
            return (
              <div
                key={object.id}
                className="absolute -translate-x-1/2 -translate-y-1/2 overflow-hidden rounded-md"
                style={{
                  left: `${pos.x * 100}%`,
                  top: `${pos.y * 100}%`,
                  width: w,
                  height: w,
                  opacity,
                  transform: `translate(-50%, -50%) rotate(${rotation}deg)`,
                }}
              >
                {ref != null && ref.role === "OBJECT" ? (
                  <ManifestImage
                    assetId={ref.assetId}
                    alt={object.id}
                    className="h-full w-full object-cover border border-border bg-surface-alt"
                  />
                ) : (
                  <ProceduralGlyph type={object.type ?? ""} id={object.id} />
                )}
              </div>
            );
          })}
          {activeEffects.map((e, i) => {
            const center = e.type === "GLOW" && e.objectId && cinematicFrame?.objects[e.objectId]
              ? cinematicFrame.objects[e.objectId]!.position
              : e.center;
            const cx = `${center.x * 100}%`;
            const cy = `${center.y * 100}%`;
            if (e.type === "MIST") {
              return (
                <div
                  key={i}
                  className="pointer-events-none absolute inset-0"
                  style={{
                    background: `linear-gradient(to bottom, rgba(243,234,211,${(e.intensity * 0.85).toFixed(2)}) 0%, transparent 62%, rgba(243,234,211,${(e.intensity * 0.5).toFixed(2)}) 100%)`,
                  }}
                />
              );
            }
            if (e.type === "GLOW") {
              return (
                <div
                  key={i}
                  className="pointer-events-none absolute inset-0"
                  style={{
                    background: `radial-gradient(circle at ${cx} ${cy}, rgba(232,184,109,${(e.intensity * 0.5).toFixed(2)}) 0%, transparent 40%)`,
                  }}
                />
              );
            }
            if (e.type === "FADE_OUT") {
              return <div key={i} className="pointer-events-none absolute inset-0 bg-[#2a2018]" />;
            }
            if (e.type === "WATER_RIPPLE") {
              return (
                <div
                  key={i}
                  className="pointer-events-none absolute rounded-full border-2 border-[#7ba7bc]/60"
                  style={{
                    left: cx, top: cy, width: 120, height: 120,
                    transform: "translate(-50%, -50%)",
                    opacity: 0.4,
                  }}
                />
              );
            }
            return null;
          })}
        </div>
      </div>

      {allowWater && (
        <label className="flex items-center gap-2 text-xs text-ink">
          <span className="whitespace-nowrap">Học viên kéo mực nước:</span>
          <input
            type="range" min="0" max="1" step="0.01"
            value={(state.waterLevel as number) ?? 0.3}
            className="w-full accent-brand"
            onChange={(e) => setWaterOverride(Number(e.target.value))}
          />
        </label>
      )}
      {allowTap && tappedId && (
        <p className="rounded-md border border-brand/30 bg-brand/5 px-3 py-2 text-xs text-ink">
          {(manifest.map?.locations ?? []).find((l) => l.id === tappedId)?.description ||
            "Địa điểm này chưa có giải thích."}
        </p>
      )}
      {manifest.disclaimer && (
        <p className="text-[11px] italic text-ink-muted">{manifest.disclaimer}</p>
      )}

      {/* Điều khiển phát */}
      <div className="flex items-center gap-2" data-testid="playback-controls">
        <Button variant="outline" size="sm" disabled={steps.length === 0 || index === 0} onClick={() => go(index - 1)} aria-label="Bước trước">
          <SkipBack className="size-4" />
        </Button>
        <Button
          variant="secondary"
          size="sm"
          disabled={steps.length === 0}
          onClick={togglePlay}
          data-testid="play-toggle"
        >
          {playing ? <Pause className="mr-1 size-4" /> : status === "finished" ? <RotateCcw className="mr-1 size-4" /> : <Play className="mr-1 size-4" />}
          {playing ? "Tạm dừng" : status === "finished" ? "Phát lại" : "Phát"}
        </Button>
        <Button variant="outline" size="sm" disabled={index >= steps.length - 1} onClick={() => go(index + 1)} aria-label="Bước sau">
          <SkipForward className="size-4" />
        </Button>
        <span className="ml-2 text-xs text-ink-muted" data-testid="step-label">
          {steps.length === 0 ? "Chưa có bước" : `Bước ${index + 1}/${steps.length} — ${step?.title ?? ""}`}
        </span>
        {audioForStep.length > 0 && (
          <span
            className="ml-auto rounded border border-brand/40 bg-brand/10 px-2 py-0.5 text-[10px] font-semibold text-brand"
            title={audioForStep.map((c) => `${c.cue}: ${c.assetRef}`).join(" · ")}
          >
            ♪ {audioForStep.length} cue
          </span>
        )}
      </div>
    </div>
  );
}

/** Glyph procedural SVG — parity với _ProceduralObjectPainter Flutter.
 * BOAT/DECOY = thuyền stylized (DECOY buồm xanh lục, BOAT buồm đỏ),
 * STAKE = cọc nhọn, MARKER/LOCATION = chấm+vòng, LABEL/TEXT = ô nhãn,
 * WATER = gợn sóng. Không phải "ảnh cinematic" — chỉ để track có cái
 * để animate khi không có assetRef. */
function ProceduralGlyph({ type, id }: { type: string; id: string }) {
  const w = 64;
  const h = 64;
  const boat = type === "BOAT" || type === "DECOY";
  const sail = type === "DECOY" ? "#2f5d3a" : "#b3402f";
  return (
    <svg viewBox={`0 0 ${w} ${h}`} className="h-full w-full" aria-label={id}>
      {boat && (
        <>
          <path
            d={`M${w * 0.18} ${h * 0.62} L${w * 0.82} ${h * 0.62} L${w * 0.70} ${h * 0.78} L${w * 0.30} ${h * 0.78} Z`}
            fill="#4a3226"
          />
          <path
            d={`M${w * 0.5} ${h * 0.56} L${w * 0.5} ${h * 0.18} L${w * 0.72} ${h * 0.56} Z`}
            fill={sail}
            opacity={0.9}
          />
        </>
      )}
      {type === "STAKE" && (
        <>
          <path
            d={`M${w * 0.46} ${h * 0.22} L${w * 0.54} ${h * 0.22} L${w * 0.58} ${h * 0.85} L${w * 0.42} ${h * 0.85} Z`}
            fill="#3a2c22"
          />
          <path
            d={`M${w * 0.5} ${h * 0.08} L${w * 0.56} ${h * 0.24} L${w * 0.44} ${h * 0.24} Z`}
            fill="#b3402f"
          />
        </>
      )}
      {(type === "MARKER" || type === "LOCATION") && (
        <>
          <circle cx={w / 2} cy={h / 2} r={w * 0.34} fill="none" stroke="#b3402f" strokeWidth={w * 0.06} opacity={0.9} />
          <circle cx={w / 2} cy={h / 2} r={w * 0.16} fill="#3a2c22" />
        </>
      )}
      {(type === "LABEL" || type === "TEXT") && (
        <>
          <rect x={w * 0.06} y={h * 0.3} width={w * 0.88} height={h * 0.4} rx={4} fill="#f3ead3" stroke="#c9b58a" />
          <text x={w / 2} y={h * 0.55} textAnchor="middle" fontSize={h * 0.22} fontWeight={700} fill="#3a2c22">?</text>
        </>
      )}
      {type === "WATER" && (
        <>
          <path
            d={`M${w * 0.12} ${h * 0.42} Q${w * 0.32} ${h * 0.30} ${w * 0.5} ${h * 0.42} Q${w * 0.68} ${h * 0.54} ${w * 0.88} ${h * 0.42}`}
            fill="none"
            stroke="#2f5d3a"
            strokeWidth={w * 0.05}
            strokeLinecap="round"
            opacity={0.6}
          />
          <path
            d={`M${w * 0.12} ${h * 0.62} Q${w * 0.32} ${h * 0.50} ${w * 0.5} ${h * 0.62} Q${w * 0.68} ${h * 0.74} ${w * 0.88} ${h * 0.62}`}
            fill="none"
            stroke="#2f5d3a"
            strokeWidth={w * 0.05}
            strokeLinecap="round"
            opacity={0.6}
          />
        </>
      )}
    </svg>
  );
}

/* ==================== RIVER_TIDE preview ==================== */

function RiverPreview({ manifest, state }: { manifest: AnimationManifest; state: Record<string, unknown> }) {
  const W = 640;
  const H = Math.round(W / (manifest.canvas?.aspectRatio ?? 1.6));
  const water = (state.waterLevel as number) ?? 0.3;
  const boat = (state.boatProgress as number) ?? 0;
  const decoy = (state.decoyProgress as number) ?? 0;
  const counter = (state.counterattackProgress as number) ?? 0;
  const obstructed = state.obstructed === true;
  const highlight = state.highlightStakes === true;
  const summary = state.showSequenceSummary === true;
  const stakes = manifest.river?.stakes ?? [];
  const visOverride = (state.stakeVisibility ?? {}) as Record<string, number>;

  const waterTop = H * (1 - water);
  return (
    <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Xem trước cảnh sông" className="w-full" data-testid="river-scene">
      <rect width={W} height={H} fill="#e9dcbb" />
      <rect y={waterTop} width={W} height={H - waterTop} fill="#3f6f9e" opacity={0.85} data-testid="water-rect" />
      <line x1={0} y1={waterTop} x2={W} y2={waterTop} stroke="#2c567e" strokeWidth="3" />
      {stakes.map((s) => {
        const vis = visOverride[s.id] ?? (s.visible === false ? 0 : 1);
        if (vis <= 0) return null;
        const tipX = s.x * W;
        const tipY = H - s.length * H;
        const exposed = tipY > waterTop;
        return (
          <polygon
            key={s.id}
            points={`${tipX - 8},${H} ${tipX},${Math.min(tipY, H)} ${tipX + 8},${H}`}
            fill={highlight ? "#d9a441" : "#6d4c33"}
            stroke={exposed ? "#b3402f" : "none"}
            strokeWidth={exposed ? 3 : 0}
            opacity={vis}
          />
        );
      })}
      {boat > 0 && (
        <g transform={`translate(${boat * W}, ${waterTop - 18})`}>
          <path d="M-30 0 L30 0 L18 14 L-18 14 Z" fill={obstructed ? "#b3402f" : "#4a3a2a"} />
          <rect x={-4} y={-16} width={8} height={16} fill="#4a3a2a" />
        </g>
      )}
      {decoy > 0 && (
        <g transform={`translate(${decoy * W}, ${waterTop - 8})`} opacity={0.7}>
          <path d="M-18 0 L18 0 L12 8 L-12 8 Z" fill="#8a7a5a" />
        </g>
      )}
      {counter > 0 && (
        <>
          <g transform={`translate(${W - counter * W * 0.4}, ${waterTop - 26})`}>
            <path d="M-24 0 L24 0 L15 11 L-15 11 Z" fill="#2f5d3a" />
          </g>
          <g transform={`translate(${W - counter * W * 0.4}, ${H - 20})`}>
            <path d="M-24 0 L24 0 L15 11 L-15 11 Z" fill="#2f5d3a" />
          </g>
        </>
      )}
      {summary && (
        <g>
          {[0, 1, 2].map((i) => (
            <rect key={i} x={40 + i * 190} y={16} width={170} height={34} rx={8} fill="#fff" stroke="#7a5a3e" />
          ))}
          <text x={125} y={38} textAnchor="middle" fontSize="12" fill="#3a2c22">Triều xuống</text>
          <text x={315} y={38} textAnchor="middle" fontSize="12" fill="#3a2c22">Cọc lộ → mắc</text>
          <text x={505} y={38} textAnchor="middle" fontSize="12" fill="#3a2c22">Phản công</text>
        </g>
      )}
    </svg>
  );
}

/* ==================== JOURNEY_MAP preview ==================== */

function MapPreview({
  manifest,
  state,
  interactive,
  tappedId,
  onTap,
}: {
  manifest: AnimationManifest;
  state: Record<string, unknown>;
  interactive: boolean;
  tappedId: string | null;
  onTap: (id: string | null) => void;
}) {
  const W = 640;
  const H = Math.round(W / (manifest.canvas?.aspectRatio ?? 1.6));
  const locations = manifest.map?.locations ?? [];
  const routes = manifest.map?.routes ?? [];
  const markerVis = (state.markerVisibility ?? {}) as Record<string, number>;
  const routeProg = (state.routeProgress ?? {}) as Record<string, number>;
  const highlight = new Set((state.markerHighlight ?? []) as string[]);
  const focused = state.focusedLocationId as string | undefined;

  return (
    <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Xem trước bản đồ" className="w-full" data-testid="map-scene">
      <rect width={W} height={H} fill="#f3ead3" />
      <path
        d={`M32 ${H * 0.75} Q${W * 0.2} ${H * 0.4} ${W * 0.45} ${H * 0.3} Q${W * 0.75} ${H * 0.18} ${W * 0.92} ${H * 0.38} Q${W * 0.98} ${H * 0.6} ${W * 0.8} ${H * 0.85} Q${W * 0.45} ${H * 0.97} 32 ${H * 0.75} Z`}
        fill="#8fb57324"
        stroke="#7a5a3e33"
      />
      {routes.map((r) => {
        const from = locations.find((l) => l.id === r.from);
        const to = locations.find((l) => l.id === r.to);
        if (!from || !to) return null;
        const pts = [
          [from.x * W, from.y * H],
          ...(r.via ?? []).map((v) => [v.x * W, v.y * H]),
          [to.x * W, to.y * H],
        ];
        const d = pts.map((p, i) => `${i === 0 ? "M" : "L"}${p[0]} ${p[1]}`).join(" ");
        const prog = routeProg[r.id] ?? 0;
        return (
          <path
            key={r.id}
            d={d}
            fill="none"
            stroke="#b3402f"
            strokeWidth="4"
            strokeLinecap="round"
            strokeDasharray="14 10"
            pathLength={100}
            strokeDashoffset={100 - prog * 100}
            opacity={prog > 0 ? 1 : 0}
          />
        );
      })}
      {locations.map((l) => {
        const vis = markerVis[l.id] ?? 0;
        if (vis <= 0) return null;
        const isFocus = focused === l.id || tappedId === l.id;
        const r = highlight.has(l.id) ? 13 : 10;
        return (
          <g
            key={l.id}
            opacity={vis}
            onClick={interactive ? () => onTap(tappedId === l.id ? null : l.id) : undefined}
            className={interactive ? "cursor-pointer" : undefined}
          >
            {isFocus && <circle cx={l.x * W} cy={l.y * H} r={r + 8} fill="none" stroke="#b3402f" strokeWidth="2" />}
            <circle
              cx={l.x * W}
              cy={l.y * H}
              r={r}
              fill={highlight.has(l.id) ? "#b3402f" : "#7a5a3e"}
              stroke="#fff"
              strokeWidth="2.5"
            />
            <text x={l.x * W} y={l.y * H + r + 16} textAnchor="middle" fontSize={13} fontWeight={700} fill="#3a2c22">
              {l.name || l.id}
            </text>
            {l.contextLabel && (
              <text x={l.x * W} y={l.y * H + r + 30} textAnchor="middle" fontSize={10} fill="#7a5a3e">
                {l.contextLabel}
              </text>
            )}
          </g>
        );
      })}
    </svg>
  );
}
