"use client";

import { Plus, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { genItemId } from "../draft-id";
import { EvidenceRefPicker } from "./evidence-ref-picker";
import { ActivityCommonFields, type EditorProps } from "./shared-fields";

interface Option extends Record<string, unknown> {
  id: string;
  text: string;
}

function readOptions(config: Record<string, unknown> | undefined, field: string): Option[] {
  const raw = config?.[field];
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((o) => o && typeof o === "object")
    .map((o) => {
      const r = o as Record<string, unknown>;
      return { ...r, id: String(r.id ?? ""), text: String(r.text ?? r.label ?? "") } as Option;
    })
    .filter((o) => o.id);
}

function readStringArray(config: Record<string, unknown> | undefined, field: string): string[] {
  const raw = config?.[field];
  return Array.isArray(raw) ? raw.map((x) => String(x ?? "")).filter(Boolean) : [];
}

/**
 * CER_CHOICE — structured Claim→Evidence→Reasoning pick with admin-authored
 * answer keys. Emits config {claims[], reasoningOptions[], evidenceOptions[],
 * acceptedClaims[], acceptedEvidenceIds[], acceptedReasoningIds[], minCorrect,
 * maxAttempts, priorEvidenceSource}. `graded:true` implied by the type itself.
 */
export function CerChoiceEditor(props: EditorProps) {
  const { activity, eventId, readOnly, onChange } = props;
  const config = activity.config ?? {};
  const claims = readOptions(config, "claims");
  const reasoning = readOptions(config, "reasoningOptions");
  const evidenceOptions = readOptions(config, "evidenceOptions");
  const acceptedClaims = readStringArray(config, "acceptedClaims");
  const acceptedReasoning = readStringArray(config, "acceptedReasoningIds");
  const acceptedEvidence = readStringArray(config, "acceptedEvidenceIds");
  const minCorrect = (config.minCorrect as number | undefined) ?? 3;
  const maxAttempts = (config.maxAttempts as number | undefined) ?? 3;
  const priorSource = String(config.priorEvidenceSource ?? "");

  function write(patch: Record<string, unknown>) {
    onChange({ config: { ...config, ...patch } });
  }

  function setOption(field: "claims" | "reasoningOptions" | "evidenceOptions", i: number, next: Option) {
    const list = field === "claims" ? claims : field === "reasoningOptions" ? reasoning : evidenceOptions;
    write({ [field]: list.map((x, j) => (j === i ? next : x)) });
  }

  function addOption(field: "claims" | "reasoningOptions" | "evidenceOptions") {
    const list = field === "claims" ? claims : field === "reasoningOptions" ? reasoning : evidenceOptions;
    write({ [field]: [...list, { id: genItemId(list.map((x) => x.id)), text: "" }] });
  }

  function removeOption(field: "claims" | "reasoningOptions" | "evidenceOptions", i: number) {
    const list = field === "claims" ? claims : field === "reasoningOptions" ? reasoning : evidenceOptions;
    const removedId = list[i]?.id;
    write({
      [field]: list.filter((_, j) => j !== i),
      // Keep key arrays consistent when an option is deleted.
      ...(field === "claims" && removedId ? { acceptedClaims: acceptedClaims.filter((x) => x !== removedId) } : {}),
      ...(field === "reasoningOptions" && removedId ? { acceptedReasoningIds: acceptedReasoning.filter((x) => x !== removedId) } : {}),
      ...(field === "evidenceOptions" && removedId ? { acceptedEvidenceIds: acceptedEvidence.filter((x) => x !== removedId) } : {}),
    });
  }

  function toggleId(field: "acceptedClaims" | "acceptedReasoningIds" | "acceptedEvidenceIds", id: string, list: string[]) {
    const s = new Set(list);
    if (s.has(id)) s.delete(id);
    else s.add(id);
    write({ [field]: Array.from(s) });
  }

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />
      <p className="rounded-md bg-brand/10 px-3 py-2 text-xs text-ink">
        Hoạt động này tự chấm: chọn đáp án đúng cho từng phần — không cần viết JSON.
      </p>

      {/* Claims */}
      <OptionListEditor
        label="Phương án kết luận (Claim) *"
        hint="Ít nhất 2 phương án. Đánh dấu phương án đúng."
        options={claims}
        accepted={acceptedClaims}
        readOnly={readOnly}
        onAdd={() => addOption("claims")}
        onChange={(i, o) => setOption("claims", i, o)}
        onRemove={(i) => removeOption("claims", i)}
        onToggleAccepted={(id) => toggleId("acceptedClaims", id, acceptedClaims)}
      />

      {/* Evidence options — use picker for the selectable pool */}
      <EvidenceRefPicker
        label="Bằng chứng học viên được chọn"
        hint="Danh sách bằng chứng hiển thị để học viên chọn. Trùng với evidenceOptions[].id."
        selectedIds={evidenceOptions.map((o) => o.id)}
        eventId={eventId}
        readOnly={readOnly}
        onChange={(next) =>
          write({ evidenceOptions: next.map((id) => ({ id })) })
        }
      />
      <EvidenceRefPicker
        label="Bằng chứng đúng (đáp án) *"
        hint="Tập con của danh sách trên — không hiển thị cho học viên."
        required
        selectedIds={acceptedEvidence}
        eventId={eventId}
        readOnly={readOnly}
        onChange={(next) => write({ acceptedEvidenceIds: next })}
      />

      {/* Reasoning options */}
      <OptionListEditor
        label="Phương án suy luận (Reasoning) *"
        hint="Ít nhất 2 phương án. Đánh dấu phương án đúng."
        options={reasoning}
        accepted={acceptedReasoning}
        readOnly={readOnly}
        onAdd={() => addOption("reasoningOptions")}
        onChange={(i, o) => setOption("reasoningOptions", i, o)}
        onRemove={(i) => removeOption("reasoningOptions", i)}
        onToggleAccepted={(id) => toggleId("acceptedReasoningIds", id, acceptedReasoning)}
      />

      {/* Policy numbers */}
      <div className="grid grid-cols-2 gap-3">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`min-${activity.id}`}>Số phần đúng tối thiểu (1-3)</Label>
          <Input
            id={`min-${activity.id}`}
            inputMode="numeric"
            className="w-24"
            value={String(minCorrect)}
            disabled={readOnly}
            onChange={(e) => {
              const v = e.target.value.trim();
              if (v === "") return write({ minCorrect: undefined });
              const n = Number(v);
              if (!Number.isNaN(n)) write({ minCorrect: n });
            }}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`att-${activity.id}`}>Số lần thử tối đa</Label>
          <Input
            id={`att-${activity.id}`}
            inputMode="numeric"
            className="w-24"
            value={String(maxAttempts)}
            disabled={readOnly}
            onChange={(e) => {
              const v = e.target.value.trim();
              if (v === "") return write({ maxAttempts: undefined });
              const n = Number(v);
              if (!Number.isNaN(n)) write({ maxAttempts: n });
            }}
          />
        </div>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`src-${activity.id}`}>Tự điền bằng chứng từ hoạt động (tuỳ chọn)</Label>
        <Input
          id={`src-${activity.id}`}
          value={priorSource}
          disabled={readOnly}
          placeholder="activity-id của EVIDENCE_SELECT trước đó"
          onChange={(e) => write({ priorEvidenceSource: e.target.value.trim() || undefined })}
        />
        <p className="text-xs text-ink-muted">
          Nếu đặt, bằng chứng học viên đã chọn ở hoạt động đó sẽ được điền sẵn.
        </p>
      </div>
    </div>
  );
}

interface OptionListProps {
  label: string;
  hint?: string;
  options: Option[];
  accepted: string[];
  readOnly?: boolean;
  onAdd: () => void;
  onChange: (i: number, o: Option) => void;
  onRemove: (i: number) => void;
  onToggleAccepted: (id: string) => void;
}

function OptionListEditor({
  label, hint, options, accepted, readOnly, onAdd, onChange, onRemove, onToggleAccepted,
}: OptionListProps) {
  return (
    <div className="flex flex-col gap-2">
      <Label>{label}</Label>
      {hint && <p className="text-xs text-ink-muted">{hint}</p>}
      {options.map((o, i) => (
        <div key={o.id} className="flex items-center gap-2">
          <input
            type="checkbox"
            className="size-4 shrink-0 accent-brand"
            title="Đáp án đúng"
            checked={accepted.includes(o.id)}
            disabled={readOnly}
            onChange={() => onToggleAccepted(o.id)}
          />
          <Input
            value={o.text}
            disabled={readOnly}
            placeholder={`Phương án ${i + 1}`}
            aria-label={`${label} ${i + 1}`}
            onChange={(e) => onChange(i, { ...o, text: e.target.value })}
          />
          {!readOnly && (
            <Button
              variant="secondary"
              className="h-9 px-2"
              disabled={options.length <= 2}
              aria-label={`Xoá phương án ${i + 1}`}
              onClick={() => onRemove(i)}
            >
              <Trash2 className="size-3.5" />
            </Button>
          )}
        </div>
      ))}
      {!readOnly && (
        <Button variant="secondary" size="sm" className="self-start" onClick={onAdd}>
          <Plus className="size-4" /> Thêm phương án
        </Button>
      )}
      {options.length < 2 && (
        <p role="alert" className="text-xs text-error">
          Cần ít nhất 2 phương án.
        </p>
      )}
      {accepted.length === 0 && options.length > 0 && (
        <p role="alert" className="text-xs text-error">
          Đánh dấu ít nhất 1 đáp án đúng để xuất bản.
        </p>
      )}
    </div>
  );
}
