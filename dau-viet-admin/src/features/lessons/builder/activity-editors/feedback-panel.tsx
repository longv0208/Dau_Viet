"use client";

import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

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
 * Feedback editor — writes activity.feedback{outcomeKey: string}. Backend
 * resolves a feedbackCode only when the key exists, so absent keys are the
 * "no feedback" state (not an empty string).
 */
export function FeedbackPanel({ activity, readOnly, onChange }: EditorProps) {
  const fb = (activity.feedback && typeof activity.feedback === "object"
    ? activity.feedback
    : {}) as Record<string, unknown>;

  function set(key: string, value: string) {
    const next = { ...fb };
    // Keep the raw value while typing — a trailing space must not be stripped
    // from the controlled input, otherwise Space "doesn't work" mid-sentence.
    // Emptiness is judged by the trimmed value: all-whitespace deletes the key.
    if (value.trim()) next[key] = value;
    else delete next[key];
    // Emit undefined instead of {} so the object stays absent when empty.
    onChange({ feedback: Object.keys(next).length ? next : undefined });
  }

  return (
    <details className="rounded-md border border-border bg-white">
      <summary className="cursor-pointer select-none px-3 py-2 text-sm font-semibold text-ink">
        Phản hồi cho học viên
        <span className="ml-2 font-normal text-xs text-ink-muted">
          {Object.values(fb).filter((v) => String(v ?? "").trim()).length > 0
            ? `(${Object.values(fb).filter((v) => String(v ?? "").trim()).length} mục đã nhập)`
            : "(tuỳ chọn)"}
        </span>
      </summary>
      <div className="flex flex-col gap-3 border-t border-border/60 p-3">
        <p className="text-xs text-ink-muted">
          Nội dung hiển thị sau mỗi lần học viên nộp câu trả lời. Bỏ trống = không hiển thị phản hồi cho trường hợp đó.
        </p>
        {OUTCOME_FIELDS.map((f) => (
        <div key={f.key} className="flex flex-col gap-1">
          <Label htmlFor={`fb-${f.key}-${activity.id}`}>{f.label}</Label>
          <Textarea
            id={`fb-${f.key}-${activity.id}`}
            rows={2}
            value={String(fb[f.key] ?? "")}
            disabled={readOnly}
            placeholder={f.hint}
            onChange={(e) => set(f.key, e.target.value)}
          />
        </div>
        ))}
      </div>
    </details>
  );
}
