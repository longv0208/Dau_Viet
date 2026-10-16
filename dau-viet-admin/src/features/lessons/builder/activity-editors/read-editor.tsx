"use client";

import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

import { ActivityCommonFields, type EditorProps } from "./shared-fields";

/** READ — config.text (optional at SAVE, ≤20_000 chars at publish). */
export function ReadEditor(props: EditorProps) {
  const { activity, readOnly, onChange } = props;
  const text = (activity.config?.text as string) ?? "";
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
          placeholder="Nhập tư liệu học viên sẽ đọc…"
          onChange={(e) =>
            onChange({ config: { ...activity.config, text: e.target.value } })
          }
        />
        <p className="text-xs text-ink-muted">
          {text.length}/20.000 ký tự — để trống cũng lưu được, nhưng nên có nội dung trước khi xuất bản.
        </p>
      </div>
    </div>
  );
}
