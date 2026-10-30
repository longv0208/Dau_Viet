"use client";

import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import type { Draft } from "./draft-model";

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

  function set(patch: Partial<NonNullable<Draft["completion"]>>) {
    onChange({
      ...draft.completion,
      requireAllRequiredStages: true,
      ...patch,
    });
  }

  return (
    <section className="flex flex-col gap-3 rounded-md border border-border bg-surface p-3">
      <h4 className="text-sm font-semibold text-ink">Điều kiện hoàn thành</h4>
      <p className="text-xs text-ink-muted">
        Mặc định học viên cần hoàn thành toàn bộ các giai đoạn và hoạt động trong bài học.
      </p>
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
