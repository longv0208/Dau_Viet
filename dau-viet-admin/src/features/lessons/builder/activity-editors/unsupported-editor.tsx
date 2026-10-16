"use client";

import { AlertTriangle } from "lucide-react";

import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

import { ACTIVITY_LABELS } from "../labels";
import { ActivityCommonFields, type EditorProps } from "./shared-fields";

/**
 * Honest fallback cho các loại chưa có trình soạn trực quan
 * (EXPLORE_MAP, REASONING_CONNECT, HYPOTHESIS_CHOICE, VERIFICATION).
 * Hiển thị config thô ở dạng chỉ-đọc — JSON được giữ nguyên khi lưu
 * vì codec bảo toàn mọi trường không mô hình hoá.
 */
export function UnsupportedEditor(props: EditorProps) {
  const { activity } = props;
  const meta = ACTIVITY_LABELS[activity.type];
  const raw = JSON.stringify(activity.config ?? {}, null, 2);

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <div className="flex items-start gap-2 rounded-md bg-warning/15 px-3 py-2 text-xs text-ink">
        <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
        <p>
          Loại hoạt động <strong>{meta?.label ?? activity.type}</strong> chưa có trình
          soạn trực quan. Nội dung bên dưới chỉ để xem — cấu hình được giữ nguyên khi
          lưu; liên hệ quản trị hệ thống nếu cần sửa JSON thủ công.
        </p>
      </div>
      <ActivityCommonFields {...props} />
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`raw-${activity.id}`}>Cấu hình thô (chỉ đọc)</Label>
        <Textarea
          id={`raw-${activity.id}`}
          rows={Math.min(12, raw.split("\n").length + 1)}
          value={raw}
          readOnly
          className="font-mono text-xs"
          aria-readonly
        />
      </div>
    </div>
  );
}
