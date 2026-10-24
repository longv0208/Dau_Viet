"use client";

import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { EvidenceRefPicker } from "./evidence-ref-picker";
import { ActivityCommonFields, type EditorProps } from "./shared-fields";

/**
 * EVIDENCE_SELECT — config.visibleEvidenceIds[≥1] + optional minRequired.
 * Picker replaces manual UUID entry; emits the same string[] contract.
 */
export function EvidenceSelectEditor(props: EditorProps) {
  const { activity, eventId, readOnly, onChange } = props;
  const ids = (activity.config?.visibleEvidenceIds as string[] | undefined) ?? [];
  const minRequired = (activity.config?.minRequired as number | undefined) ?? "";
  const graded = (activity.config?.graded as boolean | undefined) ?? false;
  const acceptedIds = (activity.config?.acceptedEvidenceIds as string[] | undefined) ?? [];

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />
      <EvidenceRefPicker
        label="Bằng chứng học viên được xem"
        hint="Học viên sẽ chọn trong danh sách này — chọn từ thư viện bằng chứng."
        required
        selectedIds={ids}
        eventId={eventId}
        readOnly={readOnly}
        onChange={(next) =>
          onChange({ config: { ...activity.config, visibleEvidenceIds: next } })
        }
      />
      <label className="flex items-center gap-2 text-sm text-ink">
        <input
          type="checkbox"
          className="size-4 accent-brand"
          checked={graded}
          disabled={readOnly}
          onChange={(e) =>
            onChange({ config: { ...activity.config, graded: e.target.checked || undefined } })
          }
        />
        Chấm điểm theo đáp án (graded)
      </label>
      {graded && (
        <>
          <EvidenceRefPicker
            label="Bằng chứng đúng (đáp án) *"
            hint="Tập con của danh sách trên — không hiển thị cho học viên."
            required
            selectedIds={acceptedIds}
            eventId={eventId}
            readOnly={readOnly}
            onChange={(next) =>
              onChange({ config: { ...activity.config, acceptedEvidenceIds: next } })
            }
          />
          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`att-${activity.id}`}>Số lần thử tối đa</Label>
            <Input
              id={`att-${activity.id}`}
              inputMode="numeric"
              className="w-28"
              value={String((activity.config?.maxAttempts as number | undefined) ?? "")}
              disabled={readOnly}
              placeholder="1"
              onChange={(e) => {
                const n = e.target.value.trim();
                const v = n === "" ? undefined : Number(n);
                if (v !== undefined && Number.isNaN(v)) return;
                onChange({ config: { ...activity.config, maxAttempts: v } });
              }}
            />
          </div>
        </>
      )}
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
