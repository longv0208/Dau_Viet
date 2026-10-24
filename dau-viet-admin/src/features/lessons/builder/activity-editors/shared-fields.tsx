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
 * TASK-0020 §P0/§P5: upstream EVIDENCE_SELECT candidates for
 * config.evidenceSource / config.priorEvidenceSource dropdowns —
 * every EVIDENCE_SELECT activity in the draft except the consumer itself.
 * Backend revalidates type + reachability at publish; the dropdown keeps
 * authors from mistyping ids.
 */
export function evidenceSelectActivities(draft: Draft | undefined, excludeId: string) {
  if (!draft) return [];
  return draft.stages.flatMap((s) =>
    s.activities
      .filter((a) => a.type === "EVIDENCE_SELECT" && a.id !== excludeId)
      .map((a) => ({ id: a.id, label: a.instruction || a.id, stageId: s.id })),
  );
}
