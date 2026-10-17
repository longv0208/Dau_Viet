"use client";

import { EvidenceRefPicker } from "./evidence-ref-picker";
import { ActivityCommonFields, type EditorProps } from "./shared-fields";

/**
 * VERIFICATION — config.visibleSourceIds[] (bằng chứng học viên được xem)
 * + config.requiredEvidenceIds[] (bằng chứng phải dùng khi kiểm chứng).
 * Backend validates shape only; reference existence is checked at publish.
 */
export function VerificationEditor(props: EditorProps) {
  const { activity, eventId, readOnly, onChange } = props;
  const config = activity.config ?? {};
  const visibleIds = (config.visibleSourceIds as string[] | undefined) ?? [];
  const requiredIds = (config.requiredEvidenceIds as string[] | undefined) ?? [];

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />

      <EvidenceRefPicker
        label="Bằng chứng học viên được xem"
        hint="Học viên đối chiếu giả thuyết đã chọn với các nguồn này để kết luận củng cố hay bác bỏ."
        selectedIds={visibleIds}
        eventId={eventId}
        readOnly={readOnly}
        onChange={(next) => onChange({ config: { ...config, visibleSourceIds: next } })}
      />

      <EvidenceRefPicker
        label="Bằng chứng bắt buộc phải dùng"
        hint="Bằng chứng học viên phải trích trong phần kiểm chứng (không hiển thị cho học viên)."
        selectedIds={requiredIds}
        eventId={eventId}
        readOnly={readOnly}
        onChange={(next) => onChange({ config: { ...config, requiredEvidenceIds: next } })}
      />
    </div>
  );
}
