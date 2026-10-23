"use client";

import { useEffect, useMemo, useState } from "react";
import { Pause, Play, SkipBack, SkipForward } from "lucide-react";

import { Button } from "@/components/ui/button";
import { useAssetObjectUrl } from "@/features/assets/use-asset-object-url";

import type { AnimationManifest, ManifestStep } from "../animation-types";

/** Ảnh nền preview — tải qua BFF có auth, một lần (không per-frame). */
function ManifestImage({ assetId, alt, className }: { assetId: string; alt: string; className?: string }) {
  const { src } = useAssetObjectUrl(`/api/v1/admin/assets/${assetId}/content`);
  if (!src) return null;
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={src} alt={alt} className={className} />;
}

/**
 * Preview tương tác thật: đọc manifest.steps[].targetState và vẽ lại
 * hình học cảnh bằng SVG (rect/circle/path) — đơn giản nhưng phản ánh
 * đúng dữ liệu manifest, không phải stub. Hỗ trợ phát tự động theo
 * durationMs + tương tác WATER_LEVEL_CONTROL / TAP_TO_EXPLORE.
 */
export function ScenePreview({ manifest }: { manifest: AnimationManifest }) {
  const steps = manifest.steps ?? [];
  const [index, setIndex] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [waterOverride, setWaterOverride] = useState<number | null>(null);
  const [tappedId, setTappedId] = useState<string | null>(null);

  const step: ManifestStep | undefined = steps[Math.min(index, steps.length - 1)];

  // Trạng thái hiệu lực = initialState gộp targetState của bước đang chọn.
  const state = useMemo(() => {
    const merged: Record<string, unknown> = { ...(manifest.initialState ?? {}) };
    if (step?.targetState) {
      for (const [k, v] of Object.entries(step.targetState)) {
        if (v && typeof v === "object" && !Array.isArray(v) && typeof merged[k] === "object" && merged[k]) {
          merged[k] = { ...(merged[k] as object), ...(v as object) };
        } else {
          merged[k] = v;
        }
      }
    }
    if (waterOverride != null) merged.waterLevel = waterOverride;
    return merged;
  }, [manifest.initialState, step, waterOverride]);

  // Phát tự động: hết durationMs → bước kế; hết danh sách → dừng.
  useEffect(() => {
    if (!playing || steps.length === 0) return;
    const ms = Math.max(500, step?.durationMs ?? 4000);
    const t = setTimeout(() => {
      if (index < steps.length - 1) setIndex(index + 1);
      else setPlaying(false);
    }, ms);
    return () => clearTimeout(t);
  }, [playing, index, steps.length, step?.durationMs]);

  const go = (i: number) => {
    setIndex(Math.max(0, Math.min(i, steps.length - 1)));
    setWaterOverride(null);
  };

  const allowWater = step?.allowedInteractions?.includes("WATER_LEVEL_CONTROL");
  const allowTap = step?.allowedInteractions?.includes("TAP_TO_EXPLORE");

  const aspect = manifest.canvas?.aspectRatio ?? 1.6;
  const assets = manifest.assets ?? [];
  const objects = manifest.objects ?? [];

  // Ảnh nền: map.backgroundAssetId → assets[] role BACKGROUND đầu tiên.
  const bgAssetId = manifest.map?.backgroundAssetId ??
    assets.find((a) => a.role === "BACKGROUND")?.assetId;
  // Vật thể ảnh: objects[] có assetRef → assets[] entry role OBJECT.
  const objectLayers = useMemo(() => {
    const byKey = new Map(assets.map((a) => [a.id, a]));
    return objects
      .filter((o) => o.visible !== false && o.assetRef && byKey.get(o.assetRef)?.role === "OBJECT")
      .map((o) => ({ object: o, ref: byKey.get(o.assetRef!)! }))
      .sort((a, b) => (a.object.layer ?? 0) - (b.object.layer ?? 0));
  }, [assets, objects]);

  return (
    <div className="flex flex-col gap-3">
      <div
        className="relative overflow-hidden rounded-lg border border-border bg-[#f3ead3]"
        style={{ aspectRatio: String(aspect) }}
      >
        {/* Ảnh nền (mờ, dưới painter) — preview parity với Flutter. */}
        {bgAssetId && (
          <ManifestImage
            assetId={bgAssetId}
            alt={assets.find((a) => a.assetId === bgAssetId)?.assetId ?? "Nền minh họa"}
            className="absolute inset-0 h-full w-full object-cover opacity-45"
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
        {/* Vật thể ảnh theo tọa độ chuẩn hóa + layer — preview parity. */}
        {objectLayers.map(({ object, ref }) => {
          const w = `${Math.max(24, Math.round((object.scale ?? 0.12) * 640))}px`;
          const x = (object.position?.x ?? 0.5) * 100;
          const y = (object.position?.y ?? 0.5) * 100;
          return (
            <div
              key={object.id}
              className="absolute -translate-x-1/2 -translate-y-1/2 overflow-hidden rounded-md border border-border bg-surface-alt"
              style={{ left: `${x}%`, top: `${y}%`, width: w, height: w }}
            >
              <ManifestImage
                assetId={ref.assetId}
                alt={object.id}
                className="h-full w-full object-cover"
              />
            </div>
          );
        })}
      </div>

      {/* Chú giải tương tác */}
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
      <div className="flex items-center gap-2">
        <Button variant="outline" size="sm" disabled={steps.length === 0 || index === 0} onClick={() => go(index - 1)} aria-label="Bước trước">
          <SkipBack className="size-4" />
        </Button>
        <Button
          variant="secondary"
          size="sm"
          disabled={steps.length === 0}
          onClick={() => {
            if (index >= steps.length - 1) setIndex(0);
            setPlaying((p) => !p);
          }}
        >
          {playing ? <Pause className="mr-1 size-4" /> : <Play className="mr-1 size-4" />}
          {playing ? "Tạm dừng" : "Phát"}
        </Button>
        <Button variant="outline" size="sm" disabled={index >= steps.length - 1} onClick={() => go(index + 1)} aria-label="Bước sau">
          <SkipForward className="size-4" />
        </Button>
        <span className="ml-2 text-xs text-ink-muted">
          {steps.length === 0 ? "Chưa có bước" : `Bước ${index + 1}/${steps.length} — ${step?.title ?? ""}`}
        </span>
      </div>
    </div>
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
    <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Xem trước cảnh sông" className="w-full">
      <rect width={W} height={H} fill="#e9dcbb" />
      {/* Nước */}
      <rect y={waterTop} width={W} height={H - waterTop} fill="#3f6f9e" opacity={0.85} />
      <line x1={0} y1={waterTop} x2={W} y2={waterTop} stroke="#2c567e" strokeWidth="3" />
      {/* Bãi cọc */}
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
      {/* Thuyền địch — mắc cọc thì đỏ */}
      {boat > 0 && (
        <g transform={`translate(${boat * W}, ${waterTop - 18})`}>
          <path d="M-30 0 L30 0 L18 14 L-18 14 Z" fill={obstructed ? "#b3402f" : "#4a3a2a"} />
          <rect x={-4} y={-16} width={8} height={16} fill="#4a3a2a" />
        </g>
      )}
      {/* Thuyền dụ */}
      {decoy > 0 && (
        <g transform={`translate(${decoy * W}, ${waterTop - 8})`} opacity={0.7}>
          <path d="M-18 0 L18 0 L12 8 L-12 8 Z" fill="#8a7a5a" />
        </g>
      )}
      {/* Thuyền phản công hai cánh */}
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
      {/* Sơ đồ chuỗi tổng kết */}
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
    <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Xem trước bản đồ" className="w-full">
      <rect width={W} height={H} fill="#f3ead3" />
      <path
        d={`M32 ${H * 0.75} Q${W * 0.2} ${H * 0.4} ${W * 0.45} ${H * 0.3} Q${W * 0.75} ${H * 0.18} ${W * 0.92} ${H * 0.38} Q${W * 0.98} ${H * 0.6} ${W * 0.8} ${H * 0.85} Q${W * 0.45} ${H * 0.97} 32 ${H * 0.75} Z`}
        fill="#8fb57324"
        stroke="#7a5a3e33"
      />
      {/* Tuyến với strokeDashoffset theo routeProgress */}
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
      {/* Marker */}
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
            <text x={l.x * W} y={l.y * H + r + 16} textAnchor="middle" fontSize="13" fontWeight="700" fill="#3a2c22">
              {l.name || l.id}
            </text>
            {l.contextLabel && (
              <text x={l.x * W} y={l.y * H + r + 30} textAnchor="middle" fontSize="10" fill="#7a5a3e">
                {l.contextLabel}
              </text>
            )}
          </g>
        );
      })}
    </svg>
  );
}
