"use client";

import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";

import { EvidenceRefPicker } from "./evidence-ref-picker";
import {
  ActivityCommonFields,
  evidenceSelectActivities,
  type EditorProps,
} from "./shared-fields";

/**
 * VERIFICATION — config.visibleSourceIds[] (bằng chứng học viên được xem)
 * + config.requiredEvidenceIds[] (bằng chứng phải dùng khi kiểm chứng)
 * + config.evidenceSource (TASK-0020 §P0/§P5: EVIDENCE_SELECT upstream mà
 * server dùng để lấy bằng chứng đã thu thập — không tin evidence ids từ
 * client). Backend validates shape only; reference existence is checked
 * at publish.
 */
export function VerificationEditor(props: EditorProps) {
  const { activity, stage, eventId, draft, readOnly, onChange } = props;
  const config = activity.config ?? {};
  const visibleIds = (config.visibleSourceIds as string[] | undefined) ?? [];
  const requiredIds = (config.requiredEvidenceIds as string[] | undefined) ?? [];
  const evidenceSource = String(config.evidenceSource ?? "");
  const sourceCandidates = evidenceSelectActivities(draft, activity.id, {
    stageId: stage.id,
    activityId: activity.id,
    required: activity.required,
  });

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border bg-white p-3">
      <ActivityCommonFields {...props} />

      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`evsrc-${activity.id}`}>Nguồn bằng chứng đã thu thập</Label>
        <Select
          id={`evsrc-${activity.id}`}
          value={evidenceSource}
          disabled={readOnly}
          onChange={(e) =>
            onChange({
              config: { ...config, evidenceSource: e.target.value || undefined },
            })
          }
        >
          <option value="">— không dùng (snapshot cũ) —</option>
          {sourceCandidates.map((c) => (
            <option key={c.id} value={c.id}>
              {c.label} ({c.stageId})
            </option>
          ))}
        </Select>
        <p className="text-xs text-ink-muted">
          Server chấm kiểm chứng dựa trên bằng chứng học viên đã chọn ở hoạt
          động EVIDENCE_SELECT này — không tin dữ liệu client gửi. Nguồn phải
          nằm ở giai đoạn trước (hoặc cùng giai đoạn, đứng trước trong flow).
        </p>
      </div>

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

      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`vfatt-${activity.id}`}>Số lần kiểm chứng tối đa</Label>
        <Input
          id={`vfatt-${activity.id}`}
          inputMode="numeric"
          className="w-28"
          value={String((config.maxAttempts as number | undefined) ?? "")}
          disabled={readOnly}
          placeholder="Không giới hạn"
          onChange={(e) => {
            const n = e.target.value.trim();
            const v = n === "" ? undefined : Number(n);
            if (v !== undefined && Number.isNaN(v)) return;
            onChange({ config: { ...config, maxAttempts: v } });
          }}
        />
        <p className="text-xs text-ink-muted">
          Để trống = không giới hạn (mặc định cũ). Khi hết lượt ở kết quả
          PARTIAL/CONTRADICTED, hoạt động tính là đã duyệt (exhausted) và học
          viên đi tiếp — kết quả không được nâng thành SUPPORTED; phản hồi
          "Khi hết lượt thử" ở phần trên sẽ hiển thị cho học viên.
        </p>
      </div>
    </div>
  );
}
