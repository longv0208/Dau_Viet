"use client";

import { RotateCcw } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

import { defaultFeedbackForActivity } from "../draft-model";
import type { EditorProps } from "./shared-fields";

/** Outcome keys the learning engine looks up inside activity.feedback
 * (AbstractActivityHandler.feedbackFor). Only keys present are emitted —
 * an empty textbox deletes the key instead of saving "". */
const OUTCOME_FIELDS: { key: string; label: string; hint: string }[] = [
  { key: "COMPLETED", label: "Khi hoàn thành đúng", hint: "Thông báo sau khi học viên làm đúng." },
  { key: "INCORRECT", label: "Khi trả lời chưa đúng", hint: "Phản hồi khi học viên chọn sai — nên khuyến khích thử lại." },
  { key: "PARTIAL", label: "Khi đúng một phần", hint: "Dùng cho hoạt động có nhiều phần (VERIFICATION, MATCHING)." },
  { key: "SUPPORTED", label: "Khi giả thuyết được củng cố", hint: "VERIFICATION — bằng chứng ủng hộ giả thuyết." },
  { key: "CONTRADICTED", label: "Khi giả thuyết bị bác bỏ", hint: "VERIFICATION — bằng chứng phản bác giả thuyết." },
  { key: "EXHAUSTED", label: "Khi hết lượt thử", hint: "Hiển thị khi retry budget đã cạn — học viên đi tiếp, kết quả được ghi nhận theo lần cuối. Với VERIFICATION nên ghi rõ 'đã hoàn thành lượt học nhưng chưa kiểm chứng thành công' + lời giải thích." },
];

/**
 * Feedback editor — hiển thị sẵn bộ câu phản hồi mặc định theo từng loại
 * hoạt động (Issue #47). Quản trị viên không cần nhập tay nếu giữ mặc định;
 * nếu xoá trắng một ô khi sửa rồi rời khỏi ô (blur) hoặc bấm "Khôi phục mặc định",
 * hệ thống tự điền lại câu mặc định để không bao giờ thiếu feedback khi xuất bản.
 */
export function FeedbackPanel({ activity, readOnly, onChange }: EditorProps) {
  const defaults = defaultFeedbackForActivity(activity.type);
  const fb = (activity.feedback && typeof activity.feedback === "object"
    ? activity.feedback
    : {}) as Record<string, unknown>;

  const visibleFields = OUTCOME_FIELDS.filter(
    (f) => f.key in defaults || f.key in fb,
  );

  function restoreKeyIfEmpty(key: string, value: string) {
    if (value.trim()) return;
    const fallback = defaults[key];
    if (!fallback) return;
    const next: Record<string, unknown> = { ...defaults, ...fb, [key]: fallback };
    onChange({ feedback: next });
  }

  return (
    <details className="rounded-md border border-border bg-white">
      <summary className="cursor-pointer select-none px-3 py-2 text-sm font-semibold text-ink">
        Phản hồi cho học viên
        <span className="ml-2 font-normal text-xs text-ink-muted">
          (Đã có sẵn phản hồi mặc định — nhấn để xem hoặc chỉnh sửa)
        </span>
      </summary>
      <div className="flex flex-col gap-3 border-t border-border/60 p-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <p className="text-xs text-ink-muted">
            Hệ thống đã điền sẵn phản hồi chuẩn theo loại hoạt động. Nếu xoá trống một ô, câu mặc định sẽ tự khôi phục khi rời ô hoặc lưu bài.
          </p>
          {!readOnly && (
            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={() => onChange({ feedback: defaultFeedbackForActivity(activity.type) })}
              className="h-7 px-2 text-xs"
            >
              <RotateCcw className="mr-1 size-3" aria-hidden />
              Khôi phục mặc định
            </Button>
          )}
        </div>
        {visibleFields.map((f) => {
          const currentVal =
            f.key in fb ? String(fb[f.key] ?? "") : String(defaults[f.key] ?? "");
          return (
            <div key={f.key} className="flex flex-col gap-1">
              <Label htmlFor={`fb-${f.key}-${activity.id}`}>{f.label}</Label>
              <Textarea
                id={`fb-${f.key}-${activity.id}`}
                rows={2}
                value={currentVal}
                disabled={readOnly}
                placeholder={defaults[f.key] ?? f.hint}
                onChange={(e) =>
                  onChange({ feedback: { ...defaults, ...fb, [f.key]: e.target.value } })
                }
                onBlur={(e) => restoreKeyIfEmpty(f.key, e.target.value)}
              />
            </div>
          );
        })}
      </div>
    </details>
  );
}
