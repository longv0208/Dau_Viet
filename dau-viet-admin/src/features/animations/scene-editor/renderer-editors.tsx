"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select } from "@/components/ui/select";
import { AssetPickerDialog } from "@/features/assets/asset-picker-dialog";

import type {
  AnimationManifest,
  MapLocationDto,
  MapRouteDto,
  RiverStake,
} from "../animation-types";

/** State map theo renderer — RIVER_TIDE. */
export interface StateEditorProps {
  state: Record<string, unknown>;
  readOnly?: boolean;
  onChange: (next: Record<string, unknown>) => void;
}

const num = (v: unknown, d = 0) => (typeof v === "number" ? v : d);
const bool = (v: unknown) => v === true;

/* ==================== RIVER_TIDE ==================== */

export function RiverStateFields({ state, readOnly, onChange }: StateEditorProps) {
  const set = (k: string, v: unknown) => onChange({ ...state, [k]: v });
  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <SliderField
        label="Mực nước"
        value={num(state.waterLevel, 0.3)}
        disabled={readOnly}
        onChange={(v) => set("waterLevel", v)}
      />
      <SliderField
        label="Tiến độ thuyền địch"
        value={num(state.boatProgress)}
        disabled={readOnly}
        onChange={(v) => set("boatProgress", v)}
      />
      <SliderField
        label="Dụ địch (0 = ẩn)"
        value={num(state.decoyProgress)}
        disabled={readOnly}
        onChange={(v) => set("decoyProgress", v)}
      />
      <SliderField
        label="Phản công phối hợp"
        value={num(state.counterattackProgress)}
        disabled={readOnly}
        onChange={(v) => set("counterattackProgress", v)}
      />
      <ToggleField
        label="Thuyền mắc cọc"
        checked={bool(state.obstructed)}
        disabled={readOnly}
        onChange={(v) => set("obstructed", v)}
      />
      <ToggleField
        label="Tô sáng bãi cọc"
        checked={bool(state.highlightStakes)}
        disabled={readOnly}
        onChange={(v) => set("highlightStakes", v)}
      />
      <ToggleField
        label="Sơ đồ chuỗi tổng kết"
        checked={bool(state.showSequenceSummary)}
        disabled={readOnly}
        onChange={(v) => set("showSequenceSummary", v)}
      />
    </div>
  );
}

/** Bãi cọc của RIVER_TIDE — bảng cọc (id, x, chiều dài, hiển thị). */
export function RiverStakesEditor({
  manifest,
  readOnly,
  onChange,
}: {
  manifest: AnimationManifest;
  readOnly?: boolean;
  onChange: (m: Partial<AnimationManifest>) => void;
}) {
  const stakes = manifest.river?.stakes ?? [];
  const set = (next: RiverStake[]) => onChange({ river: { ...manifest.river, stakes: next } });
  return (
    <div className="flex flex-col gap-2">
      <Label>Bãi cọc ({stakes.length} cọc)</Label>
      {stakes.map((s, i) => (
        <div key={s.id || i} className="flex flex-wrap items-end gap-2 rounded-md border border-border p-2">
          <div className="w-28">
            <Label className="text-xs">Mã cọc</Label>
            <Input
              value={s.id}
              disabled={readOnly}
              onChange={(e) => set(stakes.map((x, j) => (j === i ? { ...x, id: e.target.value } : x)))}
            />
          </div>
          <div className="w-40 flex-1">
            <Label className="text-xs">Vị trí ngang (0–1)</Label>
            <input
              type="range" min="0" max="1" step="0.01"
              value={s.x}
              disabled={readOnly}
              className="w-full accent-brand"
              onChange={(e) => set(stakes.map((x, j) => (j === i ? { ...x, x: Number(e.target.value) } : x)))}
            />
            <span className="text-xs text-ink-muted">{s.x.toFixed(2)}</span>
          </div>
          <div className="w-40 flex-1">
            <Label className="text-xs">Chiều dài cọc (theo chiều cao khung)</Label>
            <input
              type="range" min="0.05" max="0.6" step="0.01"
              value={s.length}
              disabled={readOnly}
              className="w-full accent-brand"
              onChange={(e) => set(stakes.map((x, j) => (j === i ? { ...x, length: Number(e.target.value) } : x)))}
            />
            <span className="text-xs text-ink-muted">{s.length.toFixed(2)}</span>
          </div>
          <label className="flex items-center gap-1.5 text-xs">
            <input
              type="checkbox" className="size-3.5 accent-brand"
              checked={s.visible !== false}
              disabled={readOnly}
              onChange={(e) => set(stakes.map((x, j) => (j === i ? { ...x, visible: e.target.checked } : x)))}
            />
            Hiện
          </label>
          {!readOnly && (
            <Button variant="outline" size="sm" onClick={() => set(stakes.filter((_, j) => j !== i))}>
              Gỡ
            </Button>
          )}
        </div>
      ))}
      {!readOnly && (
        <Button
          variant="secondary"
          size="sm"
          className="self-start"
          onClick={() =>
            set([...stakes, { id: `stake-${stakes.length + 1}`, x: 0.5, length: 0.2, visible: true }])
          }
        >
          + Thêm cọc
        </Button>
      )}
    </div>
  );
}

/* ==================== JOURNEY_MAP ==================== */

export function MapStateFields({ state, readOnly, onChange, locations, routes }: StateEditorProps & {
  locations: MapLocationDto[];
  routes: MapRouteDto[];
}) {
  const markerVis = (state.markerVisibility ?? {}) as Record<string, number>;
  const routeProg = (state.routeProgress ?? {}) as Record<string, number>;
  const highlight = new Set((state.markerHighlight ?? []) as string[]);
  return (
    <div className="flex flex-col gap-3">
      <div>
        <Label className="text-xs">Độ hiện của địa điểm (0 = ẩn, 1 = hiện)</Label>
        {locations.map((l) => (
          <SliderField
            key={l.id}
            label={l.name || l.id}
            value={num(markerVis[l.id])}
            disabled={readOnly}
            onChange={(v) => onChange({ ...state, markerVisibility: { ...markerVis, [l.id]: v } })}
          />
        ))}
      </div>
      {routes.length > 0 && (
        <div>
          <Label className="text-xs">Tiến độ vẽ tuyến đường</Label>
          {routes.map((r) => (
            <SliderField
              key={r.id}
              label={r.id}
              value={num(routeProg[r.id])}
              disabled={readOnly}
              onChange={(v) => onChange({ ...state, routeProgress: { ...routeProg, [r.id]: v } })}
            />
          ))}
        </div>
      )}
      <div>
        <Label className="text-xs">Địa điểm tô sáng</Label>
        <div className="flex flex-wrap gap-3">
          {locations.map((l) => (
            <label key={l.id} className="flex items-center gap-1.5 text-xs text-ink">
              <input
                type="checkbox" className="size-3.5 accent-brand"
                checked={highlight.has(l.id)}
                disabled={readOnly}
                onChange={() => {
                  const next = new Set(highlight);
                  if (next.has(l.id)) next.delete(l.id);
                  else next.add(l.id);
                  onChange({ ...state, markerHighlight: [...next] });
                }}
              />
              {l.name || l.id}
            </label>
          ))}
        </div>
      </div>
      <div className="w-64">
        <Label className="text-xs">Địa điểm trung tâm của bước</Label>
        <Select
          value={(state.focusedLocationId as string) ?? ""}
          disabled={readOnly}
          onChange={(e) => onChange({ ...state, focusedLocationId: e.target.value || undefined })}
        >
          <option value="">— Không —</option>
          {locations.map((l) => (
            <option key={l.id} value={l.id}>
              {l.name || l.id}
            </option>
          ))}
        </Select>
      </div>
    </div>
  );
}

/** Canvas schematic đặt địa điểm — click thêm, chọn để sửa. */
export function JourneyMapEditor({
  manifest,
  readOnly,
  onChange,
}: {
  manifest: AnimationManifest;
  readOnly?: boolean;
  onChange: (m: Partial<AnimationManifest>) => void;
}) {
  const map = manifest.map ?? {};
  const locations = map.locations ?? [];
  const routes = map.routes ?? [];
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [pickerOpen, setPickerOpen] = useState(false);

  const setMap = (patch: Partial<NonNullable<AnimationManifest["map"]>>) =>
    onChange({ map: { ...map, ...patch } });

  const onCanvasClick = (e: React.MouseEvent<SVGSVGElement>) => {
    if (readOnly) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width;
    const y = (e.clientY - rect.top) / rect.height;
    const id = `loc-${locations.length + 1}`;
    setMap({
      locations: [
        ...locations,
        { id, name: `Điểm ${locations.length + 1}`, x: Number(x.toFixed(3)), y: Number(y.toFixed(3)) },
      ],
    });
    setSelectedId(id);
  };

  const updateLoc = (i: number, patch: Partial<MapLocationDto>) =>
    setMap({ locations: locations.map((l, j) => (j === i ? { ...l, ...patch } : l)) });

  const selected = locations.find((l) => l.id === selectedId);

  return (
    <div className="flex flex-col gap-4">
      {/* Canvas schematic — click để đặt marker */}
      <div>
        <Label className="text-xs">
          Bản đồ schematic — {readOnly ? "xem trước vị trí" : "bấm lên bản đồ để thêm địa điểm"}
        </Label>
        <svg
          viewBox="0 0 640 400"
          role="img"
          aria-label="Bản đồ schematic đặt địa điểm"
          onClick={onCanvasClick}
          className="mt-1 w-full cursor-crosshair rounded-md border border-border bg-[#f3ead3]"
        >
          {/* Mảng đất liền mềm */}
          <path
            d="M32 300 Q128 160 288 120 Q480 72 589 152 Q627 240 512 340 Q288 388 32 300 Z"
            fill="#8fb57324"
            stroke="#7a5a3e33"
          />
          {/* Tuyến đứt nét */}
          {routes.map((r) => {
            const from = locations.find((l) => l.id === r.from);
            const to = locations.find((l) => l.id === r.to);
            if (!from || !to) return null;
            const pts = [
              [from.x * 640, from.y * 400],
              ...(r.via ?? []).map((v) => [v.x * 640, v.y * 400] as const),
              [to.x * 640, to.y * 400],
            ];
            const d = pts
              .map((p, i) => `${i === 0 ? "M" : "L"}${p[0]} ${p[1]}`)
              .join(" ");
            return (
              <path
                key={r.id}
                d={d}
                fill="none"
                stroke="#b3402f"
                strokeWidth="3"
                strokeDasharray="10 8"
                strokeLinecap="round"
              />
            );
          })}
          {/* Marker địa điểm */}
          {locations.map((l) => (
            <g key={l.id} onClick={(e) => { e.stopPropagation(); setSelectedId(l.id); }}>
              <circle
                cx={l.x * 640}
                cy={l.y * 400}
                r={selectedId === l.id ? 12 : 9}
                fill={selectedId === l.id ? "#b3402f" : "#7a5a3e"}
                stroke="#fff"
                strokeWidth="2"
                className="cursor-pointer"
              />
              <text
                x={l.x * 640}
                y={l.y * 400 + 24}
                textAnchor="middle"
                fontSize="12"
                fontWeight="700"
                fill="#3a2c22"
              >
                {l.name || l.id}
              </text>
            </g>
          ))}
        </svg>
      </div>

      {/* Bảng địa điểm */}
      <div className="flex flex-col gap-2">
        <Label>Địa điểm ({locations.length})</Label>
        {locations.map((l, i) => (
          <div
            key={l.id}
            className={`flex flex-wrap items-end gap-2 rounded-md border p-2 ${
              selectedId === l.id ? "border-brand bg-brand/5" : "border-border"
            }`}
            onClick={() => setSelectedId(l.id)}
          >
            <div className="w-24">
              <Label className="text-xs">Mã</Label>
              <Input value={l.id} disabled={readOnly} onChange={(e) => updateLoc(i, { id: e.target.value })} />
            </div>
            <div className="min-w-28 flex-1">
              <Label className="text-xs">Tên hiển thị</Label>
              <Input value={l.name} disabled={readOnly} onChange={(e) => updateLoc(i, { name: e.target.value })} />
            </div>
            <div className="w-20">
              <Label className="text-xs">X</Label>
              <Input
                type="number" step="0.01" min="0" max="1" value={l.x} disabled={readOnly}
                onChange={(e) => updateLoc(i, { x: Number(e.target.value) })}
              />
            </div>
            <div className="w-20">
              <Label className="text-xs">Y</Label>
              <Input
                type="number" step="0.01" min="0" max="1" value={l.y} disabled={readOnly}
                onChange={(e) => updateLoc(i, { y: Number(e.target.value) })}
              />
            </div>
            {!readOnly && (
              <Button
                variant="outline" size="sm"
                onClick={() => setMap({ locations: locations.filter((_, j) => j !== i) })}
              >
                Gỡ
              </Button>
            )}
          </div>
        ))}
      </div>

      {/* Chi tiết địa điểm đang chọn */}
      {selected && (
        <div className="flex flex-col gap-2 rounded-md border border-brand/40 bg-brand/5 p-3">
          <Label>Giải thích cho “{selected.name || selected.id}”</Label>
          <Textarea
            rows={2}
            value={selected.description ?? ""}
            disabled={readOnly}
            placeholder="Ý nghĩa lịch sử của địa điểm — hiện khi học viên chạm vào."
            onChange={(e) =>
              updateLoc(locations.findIndex((l) => l.id === selected.id), { description: e.target.value })
            }
          />
          <Label className="text-xs">Nhãn bối cảnh (VD: “Kinh đô cũ”, “Trung tâm Hán”)</Label>
          <Input
            value={selected.contextLabel ?? ""}
            disabled={readOnly}
            onChange={(e) =>
              updateLoc(locations.findIndex((l) => l.id === selected.id), { contextLabel: e.target.value })
            }
          />
        </div>
      )}

      {/* Tuyến đường */}
      <div className="flex flex-col gap-2">
        <Label>Tuyến di chuyển ({routes.length})</Label>
        {routes.map((r, i) => (
          <div key={r.id} className="flex flex-wrap items-end gap-2 rounded-md border border-border p-2">
            <div className="w-28">
              <Label className="text-xs">Mã tuyến</Label>
              <Input
                value={r.id}
                disabled={readOnly}
                onChange={(e) => setMap({ routes: routes.map((x, j) => (j === i ? { ...x, id: e.target.value } : x)) })}
              />
            </div>
            <div className="w-32">
              <Label className="text-xs">Từ</Label>
              <Select
                value={r.from}
                disabled={readOnly}
                onChange={(e) => setMap({ routes: routes.map((x, j) => (j === i ? { ...x, from: e.target.value } : x)) })}
              >
                {locations.map((l) => (
                  <option key={l.id} value={l.id}>{l.name || l.id}</option>
                ))}
              </Select>
            </div>
            <div className="w-32">
              <Label className="text-xs">Đến</Label>
              <Select
                value={r.to}
                disabled={readOnly}
                onChange={(e) => setMap({ routes: routes.map((x, j) => (j === i ? { ...x, to: e.target.value } : x)) })}
              >
                {locations.map((l) => (
                  <option key={l.id} value={l.id}>{l.name || l.id}</option>
                ))}
              </Select>
            </div>
            <div className="min-w-40 flex-1">
              <Label className="text-xs">Giải thích tuyến</Label>
              <Input
                value={r.explanation ?? ""}
                disabled={readOnly}
                onChange={(e) => setMap({ routes: routes.map((x, j) => (j === i ? { ...x, explanation: e.target.value } : x)) })}
              />
            </div>
            {!readOnly && (
              <Button
                variant="outline" size="sm"
                onClick={() => setMap({ routes: routes.filter((_, j) => j !== i) })}
              >
                Gỡ
              </Button>
            )}
          </div>
        ))}
        {!readOnly && locations.length >= 2 && (
          <Button
            variant="secondary" size="sm" className="self-start"
            onClick={() =>
              setMap({
                routes: [...routes, { id: `route-${routes.length + 1}`, from: locations[0]!.id, to: locations[1]!.id }],
              })
            }
          >
            + Thêm tuyến
          </Button>
        )}
      </div>

      {/* Ảnh nền bản đồ (tuỳ chọn) */}
      <div className="flex items-end gap-2">
        <div className="flex-1">
          <Label className="text-xs">Ảnh nền bản đồ (tuỳ chọn — mặc định nền schematic)</Label>
          <Input value={map.backgroundAssetId ?? ""} disabled className="font-mono text-xs" placeholder="— Chưa chọn —" />
        </div>
        {!readOnly && (
          <>
            <Button variant="secondary" size="sm" onClick={() => setPickerOpen(true)}>
              Chọn ảnh
            </Button>
            {map.backgroundAssetId && (
              <Button variant="outline" size="sm" onClick={() => setMap({ backgroundAssetId: undefined })}>
                Gỡ ảnh
              </Button>
            )}
          </>
        )}
        <AssetPickerDialog
          open={pickerOpen}
          onOpenChange={setPickerOpen}
          onSelect={(a) => setMap({ backgroundAssetId: a.id })}
        />
      </div>
    </div>
  );
}

/* ---------- shared small fields ---------- */

export function SliderField({
  label,
  value,
  disabled,
  onChange,
}: {
  label: string;
  value: number;
  disabled?: boolean;
  onChange: (v: number) => void;
}) {
  return (
    <div>
      <Label className="text-xs">{label}</Label>
      <div className="flex items-center gap-2">
        <input
          type="range"
          min="0" max="1" step="0.01"
          value={value}
          disabled={disabled}
          className="w-full accent-brand"
          onChange={(e) => onChange(Number(e.target.value))}
        />
        <span className="w-10 text-right text-xs text-ink-muted">{value.toFixed(2)}</span>
      </div>
    </div>
  );
}

export function ToggleField({
  label,
  checked,
  disabled,
  onChange,
}: {
  label: string;
  checked: boolean;
  disabled?: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="flex items-center gap-2 text-sm text-ink">
      <input
        type="checkbox"
        className="size-4 accent-brand"
        checked={checked}
        disabled={disabled}
        onChange={(e) => onChange(e.target.checked)}
      />
      {label}
    </label>
  );
}
