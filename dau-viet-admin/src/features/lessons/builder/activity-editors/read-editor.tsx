"use client";

import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

import { EvidenceRefPicker } from "./evidence-ref-picker";
import { ActivityCommonFields, type EditorProps } from "./shared-fields";

/** READ — config.text (optional at SAVE, ≤20_000 chars at publish)
 *  + activity.evidenceRefs (nguồn gốc tư liệu — kiểm tra ref khi publish). */
export function ReadEditor(props: EditorProps) {
  const { activity, eventId, readOnly, onChange } = props;
  const text = (activity.config?.text as string) ?? "";
  const refs = activity.evidenceRefs ?? [];
  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`text-${activity.id}`}>Nội dung đọc</Label>
        <Textarea
          id={`text-${activity.id}`}
          rows={8}
          value={text}
          disabled={readOnly}
          placeholder="Nhập tư liệu học viên sẽ đọc — có thể xuống dòng thành nhiều đoạn…"
          onChange={(e) =>
            onChange({ config: { ...activity.config, text: e.target.value } })
          }
        />
        <p className="text-xs text-ink-muted">
          {text.length}/20.000 ký tự — để trống cũng lưu được, nhưng nên có nội dung trước khi xuất bản.
        </p>
      </div>
      <EvidenceRefPicker
        label="Nguồn tư liệu (bằng chứng lịch sử)"
        hint="Gắn bằng chứng làm nguồn cho đoạn đọc — học viên thấy nguồn gốc tư liệu, hệ thống kiểm tra khi xuất bản."
        selectedIds={refs}
        eventId={eventId}
        readOnly={readOnly}
        onChange={(next) => onChange({ evidenceRefs: next })}
      />
    </div>
  );
}
