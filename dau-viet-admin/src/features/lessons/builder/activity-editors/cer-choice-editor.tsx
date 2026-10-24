"use client";

import { Plus, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";

import { genItemId } from "../draft-id";
import { EvidenceRefPicker } from "./evidence-ref-picker";
import {
  ActivityCommonFields,
  evidenceSelectActivities,
  type EditorProps,
} from "./shared-fields";

interface Option extends Record<string, unknown> {
  id: string;
  text: string;
}

/** TASK-0020 §P4: một tổ hợp đúng — {claimId, evidenceIds[], reasoningId}. */
interface Combo {
  claimId: string;
  evidenceIds: string[];
  reasoningId: string;
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

function readCombos(config: Record<string, unknown> | undefined): Combo[] {
  const raw = config?.acceptedCombos;
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((c) => c && typeof c === "object")
    .map((c) => {
      const r = c as Record<string, unknown>;
      return {
        claimId: String(r.claimId ?? ""),
        evidenceIds: Array.isArray(r.evidenceIds)
          ? r.evidenceIds.map((x) => String(x ?? "")).filter(Boolean)
          : [],
        reasoningId: String(r.reasoningId ?? ""),
      };
    })
    .filter((c) => c.claimId || c.reasoningId || c.evidenceIds.length > 0);
}

/**
 * CER_CHOICE — structured Claim→Evidence→Reasoning pick graded against
 * authored coherent combinations (TASK-0020 §P4). Emits config {claims[],
 * reasoningOptions[], evidenceOptions[], acceptedCombos[], maxAttempts,
 * priorEvidenceSource}. Full correctness requires an exact combo match —
 * per-part credit is bounded by partsCorrect/3 and never promotes.
 * `graded:true` implied by the type itself.
 */
export function CerChoiceEditor(props: EditorProps) {
  const { activity, stage, eventId, draft, readOnly, onChange } = props;
  const config = activity.config ?? {};
  const claims = readOptions(config, "claims");
  const reasoning = readOptions(config, "reasoningOptions");
  const evidenceOptions = readOptions(config, "evidenceOptions");
  const combos = readCombos(config);
  const maxAttempts = (config.maxAttempts as number | undefined) ?? 3;
  const priorSource = String(config.priorEvidenceSource ?? "");
  const sourceCandidates = evidenceSelectActivities(draft, activity.id, {
    stageId: stage.id,
    activityId: activity.id,
    required: activity.required,
  });

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
      // Keep combos consistent when an option is deleted.
      ...(removedId
        ? {
            acceptedCombos: combos
              .map((c) =>
                field === "claims" && c.claimId === removedId
                  ? { ...c, claimId: "" }
                  : field === "reasoningOptions" && c.reasoningId === removedId
                    ? { ...c, reasoningId: "" }
                    : field === "evidenceOptions"
                      ? { ...c, evidenceIds: c.evidenceIds.filter((x) => x !== removedId) }
                      : c,
              ),
          }
        : {}),
    });
  }

  function updateCombo(i: number, next: Combo) {
    write({ acceptedCombos: combos.map((c, j) => (j === i ? next : c)) });
  }

  function addCombo() {
    write({
      acceptedCombos: [
        ...combos,
        { claimId: claims[0]?.id ?? "", evidenceIds: [], reasoningId: reasoning[0]?.id ?? "" },
      ],
    });
  }

  function removeCombo(i: number) {
    write({ acceptedCombos: combos.filter((_, j) => j !== i) });
  }

  function toggleComboEvidence(i: number, id: string) {
    const c = combos[i];
    if (!c) return;
    const s = new Set(c.evidenceIds);
    if (s.has(id)) s.delete(id);
    else s.add(id);
    updateCombo(i, { ...c, evidenceIds: Array.from(s) });
  }

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />
      <p className="rounded-md bg-brand/10 px-3 py-2 text-xs text-ink">
        Đúng hoàn toàn = học viên chọn khớp một tổ hợp (Kết luận + Bằng chứng +
        Lập luận) bạn khai báo bên dưới — không cần viết JSON.
      </p>

      {/* Claims */}
      <OptionListEditor
        label="Phương án kết luận (Claim) *"
        hint="Ít nhất 2 phương án."
        options={claims}
        readOnly={readOnly}
        onAdd={() => addOption("claims")}
        onChange={(i, o) => setOption("claims", i, o)}
        onRemove={(i) => removeOption("claims", i)}
      />

      {/* Reasoning options */}
      <OptionListEditor
        label="Phương án suy luận (Reasoning) *"
        hint="Ít nhất 2 phương án."
        options={reasoning}
        readOnly={readOnly}
        onAdd={() => addOption("reasoningOptions")}
        onChange={(i, o) => setOption("reasoningOptions", i, o)}
        onRemove={(i) => removeOption("reasoningOptions", i)}
      />

      {/* Evidence options — the selectable pool */}
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

      {/* Accepted combinations — replaces acceptedClaims/acceptedEvidenceIds/
          acceptedReasoningIds + minCorrect (TASK-0020 §P4). */}
      <div className="flex flex-col gap-2">
        <Label>Tổ hợp đúng được chấp nhận *</Label>
        <p className="text-xs text-ink-muted">
          Mỗi tổ hợp là một cách kết luận đúng hoàn chỉnh. Thêm nhiều tổ hợp khi
          có nhiều cách diễn giải hợp lệ. Không hiển thị cho học viên.
        </p>
        {combos.map((c, i) => (
          <div
            key={i}
            className="flex flex-col gap-2 rounded-md border border-border bg-surface p-3"
          >
            <div className="flex items-center justify-between">
              <p className="text-xs font-semibold text-ink">Tổ hợp {i + 1}</p>
              {!readOnly && (
                <Button
                  variant="secondary"
                  className="h-7 px-2 text-xs text-error"
                  onClick={() => removeCombo(i)}
                  aria-label={`Xoá tổ hợp ${i + 1}`}
                >
                  <Trash2 className="size-3.5" />
                </Button>
              )}
            </div>
            <div className="grid gap-2 sm:grid-cols-2">
              <div className="flex flex-col gap-1">
                <Label className="text-[11px]">Kết luận đúng</Label>
                <Select
                  value={c.claimId}
                  disabled={readOnly}
                  onChange={(e) => updateCombo(i, { ...c, claimId: e.target.value })}
                  aria-label={`Tổ hợp ${i + 1} — kết luận`}
                >
                  <option value="">— chọn claim —</option>
                  {claims.map((o) => (
                    <option key={o.id} value={o.id}>
                      {o.text || o.id}
                    </option>
                  ))}
                </Select>
              </div>
              <div className="flex flex-col gap-1">
                <Label className="text-[11px]">Lập luận đúng</Label>
                <Select
                  value={c.reasoningId}
                  disabled={readOnly}
                  onChange={(e) => updateCombo(i, { ...c, reasoningId: e.target.value })}
                  aria-label={`Tổ hợp ${i + 1} — lập luận`}
                >
                  <option value="">— chọn reasoning —</option>
                  {reasoning.map((o) => (
                    <option key={o.id} value={o.id}>
                      {o.text || o.id}
                    </option>
                  ))}
                </Select>
              </div>
            </div>
            <div className="flex flex-col gap-1">
              <Label className="text-[11px]">Bằng chứng đúng (chọn đủ tập)</Label>
              <div className="flex flex-wrap gap-1.5">
                {evidenceOptions.map((o) => {
                  const checked = c.evidenceIds.includes(o.id);
                  return (
                    <label
                      key={o.id}
                      className={
                        "flex items-center gap-1 rounded-md border px-2 py-1 text-[11px] " +
                        (checked ? "border-brand bg-brand/5 text-ink" : "border-border text-ink-muted")
                      }
                    >
                      <input
                        type="checkbox"
                        checked={checked}
                        disabled={readOnly}
                        className="size-3 accent-brand"
                        onChange={() => toggleComboEvidence(i, o.id)}
                      />
                      {o.id}
                    </label>
                  );
                })}
                {evidenceOptions.length === 0 && (
                  <span className="text-[11px] text-ink-muted">
                    Khai báo danh sách bằng chứng phía trên trước.
                  </span>
                )}
              </div>
            </div>
          </div>
        ))}
        {!readOnly && (
          <Button
            variant="secondary"
            size="sm"
            className="self-start"
            onClick={addCombo}
            disabled={claims.length === 0 || reasoning.length === 0}
          >
            <Plus className="size-4" /> Thêm tổ hợp đúng
          </Button>
        )}
        {combos.length === 0 && (
          <p role="alert" className="text-xs text-error">
            Cần ít nhất 1 tổ hợp đúng để xuất bản.
          </p>
        )}
      </div>

      {/* Policy numbers */}
      <div className="grid grid-cols-2 gap-3">
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
        <Select
          id={`src-${activity.id}`}
          value={priorSource}
          disabled={readOnly}
          onChange={(e) => write({ priorEvidenceSource: e.target.value || undefined })}
        >
          <option value="">— không dùng —</option>
          {sourceCandidates.map((c) => (
            <option key={c.id} value={c.id}>
              {c.label} ({c.stageId})
            </option>
          ))}
        </Select>
        <p className="text-xs text-ink-muted">
          Nếu đặt, bằng chứng học viên đã chọn ở EVIDENCE_SELECT đó sẽ được điền
          sẵn và thêm vào nhóm được chọn. Nguồn phải nằm ở giai đoạn trước.
        </p>
      </div>
    </div>
  );
}

interface OptionListProps {
  label: string;
  hint?: string;
  options: Option[];
  readOnly?: boolean;
  onAdd: () => void;
  onChange: (i: number, o: Option) => void;
  onRemove: (i: number) => void;
}

function OptionListEditor({
  label, hint, options, readOnly, onAdd, onChange, onRemove,
}: OptionListProps) {
  return (
    <div className="flex flex-col gap-2">
      <Label>{label}</Label>
      {hint && <p className="text-xs text-ink-muted">{hint}</p>}
      {options.map((o, i) => (
        <div key={o.id} className="flex items-center gap-2">
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
    </div>
  );
}
