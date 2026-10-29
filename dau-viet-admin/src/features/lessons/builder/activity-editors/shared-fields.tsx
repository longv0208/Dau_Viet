"use client";

import type { Activity, Draft, Stage } from "../draft-model";
import { ACTIVITY_LABELS } from "../labels";
import { FeedbackPanel } from "./feedback-panel";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export interface EditorProps {
  stage: Stage;
  activity: Activity;
  /** Event the lesson belongs to — lets pickers default-filter evidence. */
  eventId?: string;
  /** The whole draft — lets editors offer cross-stage references
   *  (e.g. upstream EVIDENCE_SELECT dropdowns). Optional: editors that do
   *  not need it keep working when absent. */
  draft?: Draft;
  readOnly?: boolean;
  /** Merge patch into the activity (config merges via onChange({config:{...}})). */
  onChange: (patch: Partial<Activity>) => void;
}

/** Shared header: instruction + required toggle (warns inside optional stage). */
export function ActivityCommonFields({ stage, activity, readOnly, onChange }: EditorProps) {
  const blockedByOptional = Boolean(activity.required) && !(stage.required ?? false);
  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor={`inst-${activity.id}`}>Hướng dẫn cho học viên</Label>
        <Input
          id={`inst-${activity.id}`}
          value={activity.instruction ?? ""}
          disabled={readOnly}
          placeholder={`Ví dụ: Hãy đọc kỹ tư liệu sau…`}
          onChange={(e) => onChange({ instruction: e.target.value })}
        />
      </div>
      <label className="flex items-center gap-2 text-sm text-ink">
        <input
          type="checkbox"
          className="size-4 accent-brand"
          checked={activity.required ?? false}
          disabled={readOnly}
          onChange={(e) => onChange({ required: e.target.checked })}
        />
        Bắt buộc hoàn thành
      </label>
      {blockedByOptional && (
        <p role="alert" className="rounded-md bg-warning/15 px-3 py-2 text-xs text-ink">
          Hoạt động bắt buộc nằm trong giai đoạn tuỳ chọn — bài học sẽ không xuất bản được
          cho tới khi giai đoạn được đặt bắt buộc hoặc hoạt động chuyển thành tuỳ chọn.
        </p>
      )}
      <p className="text-xs text-ink-muted">
        Loại: {ACTIVITY_LABELS[activity.type].label}
      </p>
      <FeedbackPanel stage={stage} activity={activity} readOnly={readOnly} onChange={onChange} />
    </div>
  );
}

/**
 * Issue #35: ô nhập `config.maxAttempts` (1–20) cho các activity chấm tự động.
 * Để trống → backend dùng mặc định của từng handler (MC=1, DRAG_ORDER/MATCHING=3).
 */
export function MaxAttemptsField({ activity, readOnly, onChange }: EditorProps) {
  const raw = activity.config?.maxAttempts;
  const value = typeof raw === "number" ? String(raw) : "";
  return (
    <div className="flex flex-col gap-1.5">
      <Label htmlFor={`maxatt-${activity.id}`}>Số lượt thử tối đa (maxAttempts)</Label>
      <Input
        id={`maxatt-${activity.id}`}
        type="number"
        min={1}
        max={20}
        value={value}
        disabled={readOnly}
        placeholder="Mặc định theo loại (thường 3)"
        onChange={(e) => {
          const v = e.target.value;
          const n = v === "" ? undefined : Number.parseInt(v, 10);
          const config = { ...(activity.config ?? {}) };
          if (n == null || Number.isNaN(n)) {
            delete config.maxAttempts;
          } else {
            config.maxAttempts = n;
          }
          onChange({ config });
        }}
      />
      <p className="text-xs text-ink-muted">
        Hết lượt → hoạt động tự hoàn tất tiến độ (EXHAUSTED), không kẹt học viên.
      </p>
    </div>
  );
}

/**
 * TASK-0020 §P0/§P5 + round-3 FIX 2: upstream EVIDENCE_SELECT candidates for
 * config.evidenceSource / config.priorEvidenceSource dropdowns.
 * A REQUIRED consumer may only depend on a source that is guaranteed to run:
 *  - the source's stage must be required:true (optional stages are skippable),
 *  - the source activity itself must be required:true (optional siblings are
 *    skippable inside a required stage),
 *  - a same-stage source must be declared EARLIER than the consumer
 *    (siblings execute in array order).
 * Backend revalidates all of this at publish (UNGUARANTEED_SOURCE /
 * UNREACHABLE_SOURCE); the dropdown keeps authors from mistyping ids.
 */
export function evidenceSelectActivities(
  draft: Draft | undefined,
  excludeId: string,
  consumer?: { stageId: string; activityId: string; required?: boolean },
) {
  if (!draft) return [];
  return draft.stages.flatMap((s) =>
    s.activities
      .filter((a) => {
        if (a.type !== "EVIDENCE_SELECT" || a.id === excludeId) return false;
        // A required consumer can only depend on a guaranteed source;
        // optional consumers keep the looser list (backend still revalidates).
        if (consumer?.required) {
          if (!(s.required ?? false)) return false;
          if (!(a.required ?? false)) return false;
          if (s.id === consumer.stageId) {
            const srcIdx = s.activities.findIndex((x) => x.id === a.id);
            const consIdx = s.activities.findIndex((x) => x.id === consumer.activityId);
            if (srcIdx < 0 || consIdx < 0 || srcIdx >= consIdx) return false;
          }
        }
        return true;
      })
      .map((a) => ({ id: a.id, label: a.instruction || a.id, stageId: s.id })),
  );
}
