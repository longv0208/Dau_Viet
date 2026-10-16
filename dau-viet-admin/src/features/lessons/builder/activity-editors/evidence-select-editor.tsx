"use client";

import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

import { ActivityCommonFields, type EditorProps } from "./shared-fields";

/**
 * EVIDENCE_SELECT — config.visibleEvidenceIds[≥1] + optional minRequired.
 * No evidence-catalogue picker exists yet (TASK-0016); UUID textarea + warning.
 */
export function EvidenceSelectEditor(props: EditorProps) {
  const { activity, readOnly, onChange } = props;
  const ids = (activity.config?.visibleEvidenceIds as string[] | undefined) ?? [];
  const minRequired = (activity.config?.minRequired as number | undefined) ?? "";
  const text = ids.join("\n");

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`ev-${activity.id}`}>Danh sách Evidence IDs *</Label>
        <Textarea
          id={`ev-${activity.id}`}
          rows={4}
          value={text}
          disabled={readOnly}
          placeholder={"Mỗi dòng một UUID bằng chứng"}
          onChange={(e) =>
            onChange({
              config: {
                ...activity.config,
                visibleEvidenceIds: e.target.value
                  .split("\n")
                  .map((s) => s.trim())
                  .filter(Boolean),
              },
            })
          }
        />
        <p className="text-xs text-ink-muted">
          Trình chọn bằng chứng trực quan sẽ có ở TASK-0016 — hiện nhập UUID, mỗi dòng một ID.
        </p>
        {ids.length === 0 && (
          <p role="alert" className="text-xs text-error">Cần ít nhất 1 bằng chứng.</p>
        )}
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`min-${activity.id}`}>Số bằng chứng tối thiểu phải chọn</Label>
        <Input
          id={`min-${activity.id}`}
          inputMode="numeric"
          className="w-28"
          value={String(minRequired)}
          disabled={readOnly}
          placeholder="1"
          onChange={(e) => {
            const n = e.target.value.trim();
            const v = n === "" ? undefined : Number(n);
            if (v !== undefined && Number.isNaN(v)) return;
            onChange({
              config: { ...activity.config, minRequired: v },
            });
          }}
        />
      </div>
    </div>
  );
}
