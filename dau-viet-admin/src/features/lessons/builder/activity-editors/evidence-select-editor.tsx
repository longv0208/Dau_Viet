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
  // Issue #35: graded is locked ON — every EVIDENCE_SELECT in the 4-stage
  // chain auto-grades server-side; the toggle is display-only.
  const graded = true;
  const acceptedIds = (activity.config?.acceptedEvidenceIds as string[] | undefined) ?? [];

  // Wrap onChange so every config write keeps graded:true persisted —
  // the handler reads config.graded at evaluation time.
  const persistGraded = (patch: Parameters<typeof onChange>[0]) => {
    const next = { ...patch };
    next.config = { ...(patch.config ?? activity.config ?? {}), graded: true };
    onChange(next);
  };

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
          persistGraded({ config: { ...activity.config, visibleEvidenceIds: next } })
        }
      />
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
              persistGraded({ config: { ...activity.config, acceptedEvidenceIds: next } })
            }
          />
          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`att-${activity.id}`}>Số lần thử tối đa (có chấm)</Label>
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
                persistGraded({ config: { ...activity.config, maxAttempts: v } });
              }}
            />
            <p className="text-xs text-ink-muted">
              Sau số lần này hoạt động tính là đã duyệt (exhausted) — học viên
              đi tiếp, kết quả ghi theo lần cuối.
            </p>
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`rem-${activity.id}`}>Lượt sửa bài bổ sung (remedial)</Label>
            <Input
              id={`rem-${activity.id}`}
              inputMode="numeric"
              className="w-28"
              value={String((activity.config?.remedialAttempts as number | undefined) ?? "")}
              disabled={readOnly}
              placeholder="0"
              onChange={(e) => {
                const n = e.target.value.trim();
                const v = n === "" ? undefined : Number(n);
                if (v !== undefined && Number.isNaN(v)) return;
                persistGraded({ config: { ...activity.config, remedialAttempts: v } });
              }}
            />
            <p className="text-xs text-ink-muted">
              Lượt sửa thêm chỉ mở sau khi hết lượt chấm và học viên được đưa
              quay lại hoạt động này. Sau khi cạn cả hai ngân sách, câu trả lời
              đúng cũng không thay đổi kết quả đã chốt.
            </p>
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
            persistGraded({
              config: { ...activity.config, minRequired: v },
            });
          }}
        />
      </div>
    </div>
  );
}
