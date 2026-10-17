"use client";

import { Plus, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { genItemId } from "../draft-id";
import { ActivityCommonFields, type EditorProps } from "./shared-fields";

interface Hypothesis extends Record<string, unknown> {
  id: string;
  label: string;
}

/** Reads hypotheses preserving unknown item-level keys. */
function readHypotheses(config: Record<string, unknown> | undefined): Hypothesis[] {
  const raw = config?.hypotheses;
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((h) => h && typeof h === "object")
    .map((h) => {
      const r = h as Record<string, unknown>;
      return { ...r, id: String(r.id ?? ""), label: String(r.label ?? r.text ?? "") } as Hypothesis;
    })
    .filter((h) => h.id);
}

/**
 * HYPOTHESIS_CHOICE — config.hypotheses[{id,label}] ≥2. Backend validator
 * only requires 2+ hypotheses; it does not define an "expected" pick, so
 * the editor emits no invented answer key.
 */
export function HypothesisChoiceEditor(props: EditorProps) {
  const { activity, readOnly, onChange } = props;
  const hypotheses = readHypotheses(activity.config);

  function write(next: Hypothesis[]) {
    onChange({
      config: {
        ...activity.config,
        hypotheses: next.map((h) => ({ ...h, id: h.id, label: h.label })),
      },
    });
  }

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />
      <div className="flex flex-col gap-2">
        <Label>Giả thuyết cho học viên lựa chọn *</Label>
        <p className="text-xs text-ink-muted">
          Học viên sẽ chọn một giả thuyết để kiểm chứng ở các giai đoạn sau — không có đáp án đúng tại bước này.
        </p>
        {hypotheses.map((h, i) => (
          <div key={h.id} className="flex items-center gap-2">
            <span className="w-6 text-center text-xs text-ink-muted">{i + 1}</span>
            <Input
              value={h.label}
              disabled={readOnly}
              placeholder={`Giả thuyết ${i + 1} — ví dụ: Ngô Quyền chủ động chọn Bạch Đằng làm bãi trận`}
              aria-label={`Giả thuyết ${i + 1}`}
              onChange={(e) =>
                write(hypotheses.map((x, j) => (j === i ? { ...x, label: e.target.value } : x)))
              }
            />
            {!readOnly && (
              <Button
                variant="secondary"
                className="h-9 px-2"
                disabled={hypotheses.length <= 2}
                aria-label={`Xoá giả thuyết ${i + 1}`}
                onClick={() => write(hypotheses.filter((_, j) => j !== i))}
              >
                <Trash2 className="size-3.5" />
              </Button>
            )}
          </div>
        ))}
        {!readOnly && (
          <Button
            variant="secondary"
            className="self-start"
            size="sm"
            onClick={() =>
              write([...hypotheses, { id: genItemId(hypotheses.map((x) => x.id)), label: "" }])
            }
          >
            <Plus className="size-4" /> Thêm giả thuyết
          </Button>
        )}
        {hypotheses.length < 2 && (
          <p role="alert" className="text-xs text-error">
            Cần ít nhất 2 giả thuyết để tạo hoạt động.
          </p>
        )}
        {hypotheses.some((h) => !h.label.trim()) && (
          <p role="alert" className="text-xs text-error">
            Có giả thuyết chưa nhập nội dung — điền đủ hoặc xoá bớt.
          </p>
        )}
      </div>
    </div>
  );
}
