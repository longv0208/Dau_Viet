"use client";

import { ArrowDown, ArrowUp, Copy, Plus, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";

import {
  EASINGS,
  INTERACTION_CODES,
  type AnimationManifest,
  type ManifestStep,
} from "../animation-types";
import { EffectsChecklist, Section, type SectionProps } from "./editor-sections";
import { MapStateFields, RiverStateFields } from "./renderer-editors";

const EASING_LABELS: Record<string, string> = {
  linear: "Đều (linear)",
  easeIn: "Chậm dần vào (easeIn)",
  easeOut: "Chậm dần ra (easeOut)",
  easeInOut: "Mềm hai đầu (easeInOut)",
  easeInOutCubic: "Mạnh hai đầu (easeInOutCubic)",
};

const STEP_INTERACTION_LABELS: Record<string, string> = {
  WATER_LEVEL_CONTROL: "Kéo mực nước",
  TAP_TO_EXPLORE: "Chạm địa điểm",
  PREDICTION: "Câu hỏi dự đoán",
};

/** Section 6 — Dòng thời gian: danh sách bước + thêm/nhân bản/xóa/sắp xếp. */
export function TimelineSection({ manifest, readOnly, onChange }: SectionProps) {
  const steps = manifest.steps ?? [];

  const update = (i: number, patch: Partial<ManifestStep>) =>
    onChange({ steps: steps.map((s, idx) => (idx === i ? { ...s, ...patch } : s)) });

  const move = (i: number, dir: -1 | 1) => {
    const j = i + dir;
    if (j < 0 || j >= steps.length) return;
    const a = steps[i];
    const b = steps[j];
    if (!a || !b) return;
    const next = [...steps];
    next[i] = b;
    next[j] = a;
    onChange({ steps: next });
  };

  const duplicate = (i: number) => {
    const src = steps[i];
    if (!src) return;
    const copy: ManifestStep = {
      ...src,
      id: `${src.id}-copy`,
      title: `${src.title} (bản sao)`,
      targetState: src.targetState ? { ...src.targetState } : undefined,
      effects: src.effects ? [...src.effects] : undefined,
      allowedInteractions: src.allowedInteractions ? [...src.allowedInteractions] : undefined,
    };
    const next = [...steps];
    next.splice(i + 1, 0, copy);
    onChange({ steps: next });
  };

  const addStep = () => {
    const n = steps.length + 1;
    onChange({
      steps: [
        ...steps,
        {
          id: `step-${n}`,
          title: `Bước ${n}`,
          durationMs: 4000,
          easing: "easeInOut",
          targetState: {},
          effects: [],
          allowedInteractions: [],
        },
      ],
    });
  };

  return (
    <Section title={`Dòng thời gian (${steps.length} bước)`}>
      <div className="flex flex-col gap-3">
        {steps.length === 0 && (
          <p className="text-sm text-ink-muted">
            Chưa có bước nào — mỗi bước là một trạng thái đích mà cảnh chuyển tới.
          </p>
        )}
        {steps.map((s, i) => (
          <TimelineStepCard
            key={`${s.id}-${i}`}
            index={i}
            total={steps.length}
            step={s}
            manifest={manifest}
            readOnly={readOnly}
            onChange={(patch) => update(i, patch)}
            onMove={(dir) => move(i, dir)}
            onDuplicate={() => duplicate(i)}
            onDelete={() => onChange({ steps: steps.filter((_, x) => x !== i) })}
          />
        ))}
        {!readOnly && (
          <Button variant="secondary" size="sm" className="self-start" onClick={addStep}>
            <Plus className="mr-1 size-4" aria-hidden /> Thêm bước
          </Button>
        )}
      </div>
    </Section>
  );
}

/* ---------- Step card ---------- */

function TimelineStepCard({
  index,
  total,
  step,
  manifest,
  readOnly,
  onChange,
  onMove,
  onDuplicate,
  onDelete,
}: {
  index: number;
  total: number;
  step: ManifestStep;
  manifest: AnimationManifest;
  readOnly?: boolean;
  onChange: (patch: Partial<ManifestStep>) => void;
  onMove: (dir: -1 | 1) => void;
  onDuplicate: () => void;
  onDelete: () => void;
}) {
  const state = step.targetState ?? {};
  const isRiver = manifest.rendererCode === "RIVER_TIDE";
  const locations = manifest.map?.locations ?? [];
  const routes = manifest.map?.routes ?? [];

  return (
    <div className="rounded-md border border-border">
      <div className="flex items-center justify-between gap-2 border-b border-border bg-surface-alt px-3 py-2">
        <span className="text-xs font-semibold text-ink">
          Bước {index + 1}: {step.title || step.id}
        </span>
        {!readOnly && (
          <div className="flex items-center gap-1">
            <Button variant="ghost" size="sm" disabled={index === 0} onClick={() => onMove(-1)} aria-label="Đưa lên">
              <ArrowUp className="size-4" />
            </Button>
            <Button variant="ghost" size="sm" disabled={index === total - 1} onClick={() => onMove(1)} aria-label="Đưa xuống">
              <ArrowDown className="size-4" />
            </Button>
            <Button variant="ghost" size="sm" onClick={onDuplicate} aria-label="Nhân bản bước">
              <Copy className="size-4" />
            </Button>
            <Button variant="ghost" size="sm" onClick={onDelete} aria-label="Xóa bước">
              <Trash2 className="size-4" />
            </Button>
          </div>
        )}
      </div>
      <div className="grid gap-3 p-3 sm:grid-cols-2">
        <div>
          <Label className="text-xs">Mã bước</Label>
          <Input value={step.id} disabled={readOnly} onChange={(e) => onChange({ id: e.target.value })} />
        </div>
        <div>
          <Label className="text-xs">Tên bước (hiển thị)</Label>
          <Input value={step.title} disabled={readOnly} onChange={(e) => onChange({ title: e.target.value })} />
        </div>
        <div className="sm:col-span-2">
          <Label className="text-xs">Lời dẫn của bước</Label>
          <Textarea
            rows={2}
            value={step.narration ?? ""}
            disabled={readOnly}
            placeholder="Câu chữ học viên đọc trong khi cảnh chuyển…"
            onChange={(e) => onChange({ narration: e.target.value })}
          />
        </div>
        <div className="sm:col-span-2">
          <Label className="text-xs">Gợi ý tương tác (tuỳ chọn)</Label>
          <Input
            value={step.hint ?? ""}
            disabled={readOnly}
            placeholder="VD: Thử kéo mực nước xuống thấp để xem điều gì xảy ra."
            onChange={(e) => onChange({ hint: e.target.value })}
          />
        </div>
        <div>
          <Label className="text-xs">Thời lượng chuyển (ms)</Label>
          <Input
            type="number" min={500} max={20000} step={100}
            value={step.durationMs ?? 4000}
            disabled={readOnly}
            onChange={(e) => onChange({ durationMs: Number(e.target.value) })}
          />
        </div>
        <div>
          <Label className="text-xs">Đường cong chuyển động</Label>
          <Select
            value={step.easing ?? "easeInOut"}
            disabled={readOnly}
            onChange={(e) => onChange({ easing: e.target.value })}
          >
            {EASINGS.map((ez) => (
              <option key={ez} value={ez}>{EASING_LABELS[ez] ?? ez}</option>
            ))}
          </Select>
        </div>
        <div className="sm:col-span-2">
          <Label className="text-xs">Hiệu ứng của bước</Label>
          <EffectsChecklist
            value={step.effects ?? []}
            readOnly={readOnly}
            onChange={(effects) => onChange({ effects })}
          />
        </div>
        <div className="sm:col-span-2">
          <Label className="text-xs">Tương tác được mở trong bước</Label>
          <div className="flex flex-wrap gap-3">
            {INTERACTION_CODES.map((code) => (
              <label key={code} className="flex items-center gap-1.5 text-xs text-ink">
                <input
                  type="checkbox"
                  className="size-3.5 accent-brand"
                  checked={(step.allowedInteractions ?? []).includes(code)}
                  disabled={readOnly}
                  onChange={(e) => {
                    const cur = new Set(step.allowedInteractions ?? []);
                    if (e.target.checked) cur.add(code);
                    else cur.delete(code);
                    onChange({ allowedInteractions: [...cur] });
                  }}
                />
                {STEP_INTERACTION_LABELS[code] ?? code}
              </label>
            ))}
          </div>
        </div>
        <div className="sm:col-span-2">
          <Label className="text-xs">Trạng thái đích của bước</Label>
          <div className="mt-1 rounded-md border border-dashed border-border p-3">
            {isRiver ? (
              <RiverStateFields
                state={state}
                readOnly={readOnly}
                onChange={(next) => onChange({ targetState: next })}
              />
            ) : (
              <MapStateFields
                state={state}
                locations={locations}
                routes={routes}
                readOnly={readOnly}
                onChange={(next) => onChange({ targetState: next })}
              />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
