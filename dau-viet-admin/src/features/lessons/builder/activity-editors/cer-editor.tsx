"use client";

import { Plus, Trash2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { EvidenceRefPicker } from "./evidence-ref-picker";
import { ActivityCommonFields, type EditorProps } from "./shared-fields";

function readCriteria(config: Record<string, unknown> | undefined): string[] {
  const rubric = config?.rubric;
  if (!rubric || typeof rubric !== "object") return [];
  const criteria = (rubric as Record<string, unknown>).criteria;
  return Array.isArray(criteria) ? criteria.map((c) => String(c ?? "")) : [];
}

/**
 * CER — config.rubric.criteria[≥1] + config.requiredEvidenceIds[≥1].
 * Chấm điểm do backend/chấm thủ công quyết định — builder chỉ khai báo
 * tiêu chí rubric và bằng chứng bắt buộc, không tự chấm.
 */
export function CerEditor(props: EditorProps) {
  const { activity, eventId, readOnly, onChange } = props;
  const config = activity.config ?? {};
  const criteria = readCriteria(activity.config);
  const evidenceIds = (config.requiredEvidenceIds as string[] | undefined) ?? [];

  function writeCriteria(next: string[]) {
    const rubric =
      config.rubric && typeof config.rubric === "object"
        ? { ...(config.rubric as Record<string, unknown>) }
        : {};
    onChange({ config: { ...config, rubric: { ...rubric, criteria: next } } });
  }

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />

      <div className="flex flex-col gap-2">
        <Label>Tiêu chí chấm điểm *</Label>
        {criteria.map((c, i) => (
          <div key={i} className="flex items-center gap-2">
            <span className="w-6 text-center text-xs text-ink-muted">{i + 1}</span>
            <Input
              value={c}
              disabled={readOnly}
              placeholder={`Ví dụ: Luận điểm được bảo vệ bằng ≥2 bằng chứng`}
              aria-label={`Tiêu chí ${i + 1}`}
              onChange={(e) =>
                writeCriteria(criteria.map((x, j) => (j === i ? e.target.value : x)))
              }
            />
            {!readOnly && (
              <Button
                variant="secondary"
                className="h-9 px-2"
                aria-label={`Xoá tiêu chí ${i + 1}`}
                onClick={() => writeCriteria(criteria.filter((_, j) => j !== i))}
              >
                <Trash2 className="size-3.5" />
              </Button>
            )}
          </div>
        ))}
        {!readOnly && (
          <Button
            variant="secondary"
            size="sm"
            className="self-start"
            onClick={() => writeCriteria([...criteria, ""])}
          >
            <Plus className="size-4" /> Thêm tiêu chí
          </Button>
        )}
        {criteria.filter((c) => c.trim()).length === 0 && (
          <p role="alert" className="text-xs text-error">
            Cần ít nhất 1 tiêu chí không rỗng để xuất bản.
          </p>
        )}
      </div>

      <EvidenceRefPicker
        label="Bằng chứng bắt buộc phải dùng"
        hint="Học viên phải trích các bằng chứng này trong bài kết luận có dẫn chứng (không hiển thị cho học viên)."
        required
        selectedIds={evidenceIds}
        eventId={eventId}
        readOnly={readOnly}
        onChange={(next) =>
          onChange({ config: { ...config, requiredEvidenceIds: next } })
        }
      />
    </div>
  );
}
