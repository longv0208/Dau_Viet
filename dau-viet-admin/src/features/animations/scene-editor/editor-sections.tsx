"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import { AssetPickerDialog } from "@/features/assets/asset-picker-dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";

import {
  ASSET_ROLES,
  EFFECTS,
  INTERACTION_CODES,
  type AnimationManifest,
  type ManifestAssetRef,
  type ManifestObject,
  type ManifestPrediction,
} from "../animation-types";

export interface SectionProps {
  manifest: AnimationManifest;
  readOnly?: boolean;
  onChange: (patch: Partial<AnimationManifest>) => void;
}

/** Khối gấp gọn chung cho các section của Scene Editor. */
export function Section({
  title,
  children,
  defaultOpen = true,
}: {
  title: string;
  children: React.ReactNode;
  defaultOpen?: boolean;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <section className="rounded-lg border border-border bg-white">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="flex w-full items-center justify-between px-4 py-3 text-left text-sm font-semibold text-ink"
      >
        {title}
        <span aria-hidden className="text-ink-muted">
          {open ? "▾" : "▸"}
        </span>
      </button>
      {open && <div className="border-t border-border px-4 py-4">{children}</div>}
    </section>
  );
}

/* ---------- 1. Thông tin chung ---------- */

interface EventRow {
  id: string;
  title: string;
}

export function GeneralSection({
  manifest,
  eventId,
  readOnly,
  onChange,
  onEventChange,
}: SectionProps & {
  eventId?: string | null;
  onEventChange: (eventId: string | null) => void;
}) {
  const events = useQuery({
    queryKey: ["events", "list", { size: 100 }],
    queryFn: () =>
      apiFetch<PageResponse<EventRow>>(`/admin/events${toQuery({ size: 100 })}`),
  });
  return (
    <Section title="Thông tin chung">
      <div className="flex flex-col gap-3">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="m-title">Tên cảnh</Label>
          <Input
            id="m-title"
            value={manifest.title}
            disabled={readOnly}
            onChange={(e) => onChange({ title: e.target.value })}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="m-event">Sự kiện liên quan (tuỳ chọn)</Label>
          <Select
            id="m-event"
            value={eventId ?? ""}
            disabled={readOnly}
            onChange={(e) => onEventChange(e.target.value || null)}
          >
            <option value="">— Không gắn sự kiện —</option>
            {(events.data?.content ?? []).map((ev) => (
              <option key={ev.id} value={ev.id}>
                {ev.title}
              </option>
            ))}
          </Select>
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="m-objective">Mục tiêu học tập</Label>
          <Textarea
            id="m-objective"
            rows={3}
            value={manifest.learningObjective ?? ""}
            disabled={readOnly}
            placeholder="Học viên sẽ hiểu điều gì sau khi xem cảnh này…"
            onChange={(e) => onChange({ learningObjective: e.target.value })}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="m-disclaimer">Lưu ý lịch sử (bắt buộc hiển thị)</Label>
          <Textarea
            id="m-disclaimer"
            rows={2}
            value={manifest.disclaimer ?? ""}
            disabled={readOnly}
            placeholder="VD: Sơ đồ minh họa chiến thuật, không theo tỉ lệ và không phải phục dựng chính xác trận đánh."
            onChange={(e) => onChange({ disclaimer: e.target.value })}
          />
        </div>
      </div>
    </Section>
  );
}

/* ---------- 2. Canvas ---------- */

const ASPECT_OPTIONS = [
  { label: "16:10 (mặc định)", value: "1.6" },
  { label: "16:9", value: "1.7778" },
  { label: "4:3", value: "1.3333" },
  { label: "1:1", value: "1" },
];

export function CanvasSection({ manifest, readOnly, onChange }: SectionProps) {
  const ratio = manifest.canvas?.aspectRatio ?? 1.6;
  return (
    <Section title="Khung hình" defaultOpen={false}>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="m-aspect">Tỉ lệ khung hình</Label>
        <Select
          id="m-aspect"
          value={String(ratio)}
          disabled={readOnly}
          onChange={(e) =>
            onChange({
              canvas: { ...manifest.canvas, aspectRatio: Number(e.target.value) },
            })
          }
        >
          {ASPECT_OPTIONS.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </Select>
        <p className="text-xs text-ink-muted">
          Tỉ lệ chiều rộng/chiều cao của vùng vẽ — học viên thấy khung này
          trong màn hình bài học.
        </p>
      </div>
    </Section>
  );
}

/* ---------- 3. Assets ---------- */

export function AssetsSection({ manifest, readOnly, onChange }: SectionProps) {
  const [pickerOpen, setPickerOpen] = useState(false);
  const assets = manifest.assets ?? [];

  const update = (i: number, patch: Partial<ManifestAssetRef>) => {
    const next = assets.map((a, idx) => (idx === i ? { ...a, ...patch } : a));
    onChange({ assets: next });
  };

  return (
    <Section title={`Hình ảnh & tư liệu (${assets.length})`} defaultOpen={false}>
      <div className="flex flex-col gap-3">
        {assets.map((a, i) => (
          <div key={a.id || i} className="flex flex-wrap items-end gap-2 rounded-md border border-border p-3">
            <div className="min-w-40 flex-1">
              <Label>Tên gọi trong cảnh</Label>
              <Input
                value={a.id}
                disabled={readOnly}
                onChange={(e) => update(i, { id: e.target.value })}
              />
            </div>
            <div className="min-w-52 flex-1">
              <Label>Asset ID</Label>
              <Input value={a.assetId} disabled className="font-mono text-xs" />
            </div>
            <div>
              <Label>Vai trò</Label>
              <Select
                value={a.role}
                disabled={readOnly}
                onChange={(e) => update(i, { role: e.target.value })}
              >
                {ASSET_ROLES.map((r) => (
                  <option key={r} value={r}>
                    {r}
                  </option>
                ))}
              </Select>
            </div>
            {!readOnly && (
              <Button
                variant="outline"
                size="sm"
                onClick={() => onChange({ assets: assets.filter((_, x) => x !== i) })}
              >
                Gỡ
              </Button>
            )}
          </div>
        ))}
        {!readOnly && (
          <Button variant="secondary" size="sm" className="self-start" onClick={() => setPickerOpen(true)}>
            + Thêm tư liệu từ thư viện
          </Button>
        )}
        <AssetPickerDialog
          open={pickerOpen}
          onOpenChange={setPickerOpen}
          onSelect={(asset) =>
            onChange({
              assets: [
                ...assets,
                { id: asset.originalFilename?.slice(0, 30) || `asset-${assets.length + 1}`, assetId: asset.id, role: "OBJECT" },
              ],
            })
          }
        />
      </div>
    </Section>
  );
}

/* ---------- 4. Objects ---------- */

const OBJECT_TYPES = ["STAKE", "BOAT", "DECOY", "MARKER", "LABEL", "ROUTE", "BACKGROUND", "LOCATION", "WATER", "TEXT"];

export function ObjectsSection({ manifest, readOnly, onChange }: SectionProps) {
  const objects = manifest.objects ?? [];
  const update = (i: number, patch: Partial<ManifestObject>) =>
    onChange({ objects: objects.map((o, idx) => (idx === i ? { ...o, ...patch } : o)) });

  return (
    <Section title={`Vật thể (${objects.length})`} defaultOpen={false}>
      <div className="flex flex-col gap-3">
        {objects.map((o, i) => (
          <div key={o.id || i} className="flex flex-wrap items-end gap-2 rounded-md border border-border p-3">
            <div className="w-32">
              <Label>Mã vật thể</Label>
              <Input value={o.id} disabled={readOnly} onChange={(e) => update(i, { id: e.target.value })} />
            </div>
            <div className="w-36">
              <Label>Kiểu</Label>
              <Select value={o.type} disabled={readOnly} onChange={(e) => update(i, { type: e.target.value })}>
                {OBJECT_TYPES.map((t) => (
                  <option key={t} value={t}>
                    {t}
                  </option>
                ))}
              </Select>
            </div>
            <div className="w-24">
              <Label>X (0–1)</Label>
              <Input
                type="number" step="0.01" min="0" max="1"
                value={o.position?.x ?? 0}
                disabled={readOnly}
                onChange={(e) => update(i, { position: { x: Number(e.target.value), y: o.position?.y ?? 0 } })}
              />
            </div>
            <div className="w-24">
              <Label>Y (0–1)</Label>
              <Input
                type="number" step="0.01" min="0" max="1"
                value={o.position?.y ?? 0}
                disabled={readOnly}
                onChange={(e) => update(i, { position: { x: o.position?.x ?? 0, y: Number(e.target.value) } })}
              />
            </div>
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                className="size-4 accent-brand"
                checked={o.visible !== false}
                disabled={readOnly}
                onChange={(e) => update(i, { visible: e.target.checked })}
              />
              Hiển thị
            </label>
            {!readOnly && (
              <Button variant="outline" size="sm" onClick={() => onChange({ objects: objects.filter((_, x) => x !== i) })}>
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
              onChange({
                objects: [...objects, { id: `obj-${objects.length + 1}`, type: "MARKER", position: { x: 0.5, y: 0.5 }, visible: true, layer: objects.length }],
              })
            }
          >
            + Thêm vật thể
          </Button>
        )}
      </div>
    </Section>
  );
}

/* ---------- 7. Tương tác ---------- */

const INTERACTION_LABELS: Record<string, string> = {
  WATER_LEVEL_CONTROL: "Học viên tự kéo mực nước",
  TAP_TO_EXPLORE: "Chạm địa điểm để xem giải thích",
  PREDICTION: "Câu hỏi dự đoán khám phá",
};

export function InteractionsSection({ manifest, readOnly, onChange }: SectionProps) {
  const active = new Set(manifest.interactions ?? []);
  const toggle = (code: string) => {
    const next = new Set(active);
    if (next.has(code)) next.delete(code);
    else next.add(code);
    onChange({ interactions: [...next] });
  };
  return (
    <Section title="Tương tác của học viên" defaultOpen={false}>
      <div className="flex flex-col gap-2">
        {INTERACTION_CODES.map((code) => (
          <label key={code} className="flex items-center gap-2 text-sm text-ink">
            <input
              type="checkbox"
              className="size-4 accent-brand"
              checked={active.has(code)}
              disabled={readOnly}
              onChange={() => toggle(code)}
            />
            {INTERACTION_LABELS[code] ?? code}
            <code className="text-[11px] text-ink-muted">{code}</code>
          </label>
        ))}
      </div>
      {active.has("PREDICTION") && (
        <PredictionEditor
          prediction={manifest.prediction}
          readOnly={readOnly}
          onChange={(p) => onChange({ prediction: p })}
        />
      )}
    </Section>
  );
}

function PredictionEditor({
  prediction,
  readOnly,
  onChange,
}: {
  prediction?: ManifestPrediction;
  readOnly?: boolean;
  onChange: (p: ManifestPrediction | undefined) => void;
}) {
  if (!prediction) {
    return (
      <div className="mt-3">
        {!readOnly && (
          <Button
            variant="secondary"
            size="sm"
            onClick={() =>
              onChange({ question: "", options: [{ text: "" }, { text: "" }], explainedOptionIndex: 0 })
            }
          >
            + Tạo câu hỏi dự đoán
          </Button>
        )}
      </div>
    );
  }
  const setOpt = (i: number, text: string) =>
    onChange({
      ...prediction,
      options: prediction.options.map((o, idx) => (idx === i ? { text } : o)),
    });
  return (
    <div className="mt-3 flex flex-col gap-2 rounded-md border border-brand/30 bg-brand/5 p-3">
      <Label>Câu hỏi dự đoán</Label>
      <Input
        value={prediction.question}
        disabled={readOnly}
        onChange={(e) => onChange({ ...prediction, question: e.target.value })}
      />
      {prediction.options.map((o, i) => (
        <div key={i} className="flex items-center gap-2">
          <input
            type="radio"
            name="pred-correct"
            className="size-4 accent-brand"
            checked={prediction.explainedOptionIndex === i}
            disabled={readOnly}
            onChange={() => onChange({ ...prediction, explainedOptionIndex: i })}
            title="Đáp án khớp cơ chế minh họa"
          />
          <Input
            value={o.text}
            disabled={readOnly}
            placeholder={`Phương án ${i + 1}`}
            onChange={(e) => setOpt(i, e.target.value)}
          />
          {!readOnly && prediction.options.length > 2 && (
            <Button
              variant="outline"
              size="sm"
              onClick={() =>
                onChange({ ...prediction, options: prediction.options.filter((_, x) => x !== i) })
              }
            >
              Gỡ
            </Button>
          )}
        </div>
      ))}
      <div className="flex gap-2">
        {!readOnly && (
          <Button
            variant="secondary"
            size="sm"
            onClick={() => onChange({ ...prediction, options: [...prediction.options, { text: "" }] })}
          >
            + Phương án
          </Button>
        )}
        {!readOnly && (
          <Button variant="outline" size="sm" onClick={() => onChange(undefined)}>
            Xóa câu hỏi
          </Button>
        )}
      </div>
      <Label>Giải thích sau khi trả lời</Label>
      <Textarea
        rows={2}
        value={prediction.explanation ?? ""}
        disabled={readOnly}
        onChange={(e) => onChange({ ...prediction, explanation: e.target.value })}
      />
      <Label>Gợi ý khi chọn chưa đúng</Label>
      <Input
        value={prediction.retryHint ?? ""}
        disabled={readOnly}
        onChange={(e) => onChange({ ...prediction, retryHint: e.target.value })}
      />
    </div>
  );
}

/* ---------- Nguồn tham khảo (gộp vào Xuất bản) ---------- */

export function SourcesSection({ manifest, readOnly, onChange }: SectionProps) {
  const refs = manifest.sourceReferences ?? [];
  return (
    <Section title={`Nguồn tham khảo (${refs.length})`} defaultOpen={false}>
      <div className="flex flex-col gap-2">
        {refs.map((r, i) => (
          <div key={i} className="flex items-center gap-2">
            <Input
              value={r.title}
              disabled={readOnly}
              placeholder="VD: Bảo tàng Lịch sử Quốc gia — “Ngô Quyền và chiến thắng Bạch Đằng năm 938”"
              onChange={(e) =>
                onChange({
                  sourceReferences: refs.map((x, idx) => (idx === i ? { title: e.target.value } : x)),
                })
              }
            />
            {!readOnly && (
              <Button
                variant="outline"
                size="sm"
                onClick={() => onChange({ sourceReferences: refs.filter((_, x) => x !== i) })}
              >
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
            onClick={() => onChange({ sourceReferences: [...refs, { title: "" }] })}
          >
            + Thêm nguồn
          </Button>
        )}
      </div>
    </Section>
  );
}

/** Hiệu ứng bước (checkbox whitelist EFFECTS). */
export function EffectsChecklist({
  value,
  readOnly,
  onChange,
}: {
  value: string[];
  readOnly?: boolean;
  onChange: (effects: string[]) => void;
}) {
  const active = new Set(value);
  return (
    <div className="flex flex-wrap gap-3">
      {EFFECTS.map((e) => (
        <label key={e} className="flex items-center gap-1.5 text-xs text-ink">
          <input
            type="checkbox"
            className="size-3.5 accent-brand"
            checked={active.has(e)}
            disabled={readOnly}
            onChange={() => {
              const next = new Set(active);
              if (next.has(e)) next.delete(e);
              else next.add(e);
              onChange([...next]);
            }}
          />
          {e}
        </label>
      ))}
    </div>
  );
}
