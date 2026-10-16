"use client";

import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import type { Draft } from "./draft-model";
import { STAGE_LABELS } from "./labels";

interface Props {
  draft: Draft;
  readOnly?: boolean;
  onChange: (completion: Draft["completion"]) => void;
}

/**
 * Điều kiện hoàn thành bài học — completion.requireAllRequiredStages
 * (mặc định backend: true) / requiredStageIds / minScore.
 */
export function CompletionEditor({ draft, readOnly, onChange }: Props) {
  const c = draft.completion ?? {};
  const requiredStages = draft.stages.filter((s) => s.required);
  const explicitIds = c.requiredStageIds ?? [];

  function set(patch: Partial<NonNullable<Draft["completion"]>>) {
    onChange({ ...draft.completion, ...patch });
  }

  return (
    <section className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <h4 className="text-sm font-semibold text-ink">Điều kiện hoàn thành</h4>

      <label className="flex items-start gap-2 text-sm text-ink">
        <input
          type="checkbox"
          className="mt-0.5 size-4 accent-brand"
          checked={c.requireAllRequiredStages ?? true}
          disabled={readOnly}
          onChange={(e) => set({ requireAllRequiredStages: e.target.checked })}
        />
        <span>
          Yêu cầu hoàn thành tất cả giai đoạn bắt buộc
          <span className="block text-xs text-ink-muted">
            Bỏ chọn để chọn thủ công các giai đoạn phải hoàn thành.
          </span>
        </span>
      </label>

      {(c.requireAllRequiredStages ?? true) === false && (
        <div className="flex flex-col gap-1.5">
          <Label>Các giai đoạn bắt buộc phải hoàn thành</Label>
          {requiredStages.length === 0 && (
            <p className="text-xs text-ink-muted">Chưa có giai đoạn bắt buộc nào.</p>
          )}
          {requiredStages.map((s) => {
            const checked = explicitIds.includes(s.id);
            return (
              <label key={s.id} className="flex items-center gap-2 text-sm text-ink">
                <input
                  type="checkbox"
                  className="size-3.5 accent-brand"
                  checked={checked}
                  disabled={readOnly}
                  onChange={(e) =>
                    set({
                      requiredStageIds: e.target.checked
                        ? [...explicitIds, s.id]
                        : explicitIds.filter((id) => id !== s.id),
                    })
                  }
                />
                {s.title || STAGE_LABELS[s.type].label}
              </label>
            );
          })}
        </div>
      )}

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="min-score">Điểm tối thiểu (0–100, tuỳ chọn)</Label>
        <Input
          id="min-score"
          inputMode="numeric"
          className="w-28"
          disabled={readOnly}
          value={c.minScore === undefined || c.minScore === null ? "" : String(c.minScore)}
          placeholder="—"
          onChange={(e) => {
            const v = e.target.value.trim();
            const n = v === "" ? undefined : Number(v);
            if (n !== undefined && (Number.isNaN(n) || n < 0 || n > 100)) return;
            set({ minScore: n });
          }}
        />
      </div>
    </section>
  );
}
