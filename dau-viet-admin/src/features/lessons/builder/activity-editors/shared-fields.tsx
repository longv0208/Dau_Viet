"use client";

import type { Activity, Stage } from "../draft-model";
import { ACTIVITY_LABELS } from "../labels";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export interface EditorProps {
  stage: Stage;
  activity: Activity;
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
        Loại: {ACTIVITY_LABELS[activity.type].label} · ID: {activity.id}
      </p>
    </div>
  );
}
