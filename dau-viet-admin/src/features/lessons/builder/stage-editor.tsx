"use client";

import { ArrowDown, ArrowUp, Plus, Trash2 } from "lucide-react";
import { useState } from "react";

import { ActivityPicker } from "./activity-picker";
import { ActivityEditor } from "./activity-editors";
import type { Activity, ActivityType, Draft, Stage, StageType } from "./draft-model";
import { STAGE_TYPES } from "./draft-model";
import { ACTIVITY_LABELS, STAGE_LABELS } from "./labels";
import { makeActivity } from "./use-builder";
import { SectionDivider } from "@/components/atoms/section-divider";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
interface Props {
  draft: Draft;
  stage: Stage;
  /** Event the lesson belongs to — forwarded to activity editors. */
  eventId?: string;
  readOnly?: boolean;
  selectedActivityId: string | null;
  onUpdate: (patch: Partial<Stage>) => void;
  onAddActivity: (activity: Activity) => void;
  onSelectActivity: (id: string | null) => void;
  onUpdateActivity: (activityId: string, patch: Partial<Activity>) => void;
  onRemoveActivity: (activityId: string) => void;
  onMoveActivity: (activityId: string, dir: -1 | 1) => void;
}

/** Center pane — stage metadata + activity list + selected activity editor. */
export function StageEditor({
  draft,
  stage,
  eventId,
  readOnly,
  selectedActivityId,
  onUpdate,
  onAddActivity,
  onSelectActivity,
  onUpdateActivity,
  onRemoveActivity,
  onMoveActivity,
}: Props) {
  const [picking, setPicking] = useState(false);
  const [confirmActId, setConfirmActId] = useState<string | null>(null);
  const selectedActivity = stage.activities.find((a) => a.id === selectedActivityId) ?? null;

  return (
    <div className="flex flex-col gap-5">
      <SectionDivider eyebrow="THÔNG TIN" title="Cấu hình giai đoạn" />
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="flex flex-col gap-1.5 sm:col-span-2">
          <Label htmlFor="stage-title" className="font-medium text-ink-secondary">Tên giai đoạn</Label>
          <Input
            id="stage-title"
            value={stage.title ?? ""}
            disabled={readOnly}
            placeholder={STAGE_LABELS[stage.type].label}
            onChange={(e) => onUpdate({ title: e.target.value })}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="stage-type" className="font-medium text-ink-secondary">Loại giai đoạn</Label>
          <Select
            id="stage-type"
            value={stage.type}
            disabled={readOnly}
            onChange={(e) => onUpdate({ type: e.target.value as StageType })}
          >
            {STAGE_TYPES.map((t) => (
              <option key={t} value={t}>
                {STAGE_LABELS[t].label}
              </option>
            ))}
          </Select>
          <p className="text-xs text-ink-muted">{STAGE_LABELS[stage.type].description}</p>
        </div>
        <div className="flex flex-col gap-1.5">
          <Label className="font-medium text-ink-secondary">Bắt buộc hoàn thành</Label>
          <label className="flex h-11 items-center gap-2 rounded-md border border-border px-3">
            <input
              type="checkbox"
              checked={stage.required ?? false}
              disabled={readOnly}
              onChange={(e) => onUpdate({ required: e.target.checked })}
              className="size-4 accent-brand"
            />
            <span className="text-sm text-ink">
              {stage.required ? "Bắt buộc" : "Tuỳ chọn"}
            </span>
          </label>
          {!stage.required && (
            <p className="text-xs text-ink-muted">
              Giai đoạn tuỳ chọn không chặn hoàn thành bài học.
            </p>
          )}
        </div>
      </div>

      {/* nextStageIds via checkboxes */}
      <div className="flex flex-col gap-1.5">
        <Label className="font-medium text-ink-secondary">Giai đoạn tiếp theo</Label>
        <p className="text-xs text-ink-muted">
          Để trống = giai đoạn kết thúc. Chọn nhiều để rẽ nhánh.
        </p>
        <div className="flex flex-wrap gap-2">
          {draft.stages
            .filter((s) => s.id !== stage.id)
            .map((s) => {
              const checked = stage.nextStageIds?.includes(s.id) ?? false;
              return (
                <label
                  key={s.id}
                  className={
                    "flex items-center gap-1.5 rounded-md border px-2.5 py-1.5 text-xs " +
                    (checked ? "border-brand bg-brand/5 text-ink" : "border-border text-ink-muted")
                  }
                >
                  <input
                    type="checkbox"
                    checked={checked}
                    disabled={readOnly}
                    className="size-3.5 accent-brand"
                    onChange={(e) => {
                      const cur = stage.nextStageIds ?? [];
                      onUpdate({
                        nextStageIds: e.target.checked
                          ? [...cur, s.id]
                          : cur.filter((n) => n !== s.id),
                      });
                    }}
                  />
                  {s.title || STAGE_LABELS[s.type].label}
                </label>
              );
            })}
          {draft.stages.length <= 1 && (
            <span className="text-xs text-ink-muted">Cần ≥2 giai đoạn để nối chuyển tiếp.</span>
          )}
        </div>
      </div>

      {/* Activities */}
      <div className="flex flex-col gap-2">
        <SectionDivider
          eyebrow="HOẠT ĐỘNG"
          eyebrowColor="jade"
          title={`Hoạt động (${stage.activities.length})`}
          action={
            !readOnly ? (
              <Button
                variant="secondary"
                size="sm"
                onClick={() => setPicking((p) => !p)}
                aria-expanded={picking}
              >
                <Plus className="size-4" /> Thêm hoạt động
              </Button>
            ) : undefined
          }
        />

        {picking && (
          <div className="rounded-md border border-brand/40 bg-brand/5 p-3">
            <p className="mb-2 text-xs font-medium text-ink">
              Chọn loại hoạt động phù hợp với giai đoạn {STAGE_LABELS[stage.type].label}:
            </p>
            <ActivityPicker
              stageType={stage.type}
              onPick={(t: ActivityType) => {
                onAddActivity(
                  makeActivity(t, [
                    ...stage.activities.map((a) => a.id),
                    ...draft.stages.flatMap((s) => s.activities.map((a) => a.id)),
                  ]),
                );
                setPicking(false);
              }}
            />
          </div>
        )}

        <ol className="flex flex-col gap-1.5">
          {stage.activities.map((a, i) => {
            const meta = ACTIVITY_LABELS[a.type];
            const Icon = meta?.icon;
            const selected = a.id === selectedActivityId;
            return (
              <li key={a.id}>
                <div
                  className={
                    "flex items-center gap-2 rounded-md border p-2 " +
                    (selected ? "border-brand bg-brand/5" : "border-border bg-surface")
                  }
                >
                  <button
                    type="button"
                    onClick={() => onSelectActivity(selected ? null : a.id)}
                    className="flex min-w-0 flex-1 items-center gap-2 text-left"
                  >
                    {Icon && <Icon className="size-4 shrink-0 text-ink-muted" aria-hidden />}
                    <span className="min-w-0">
                      <span className="block truncate text-sm font-medium text-ink">
                        {i + 1}. {a.instruction?.slice(0, 50) || meta?.label || "Hoạt động"}
                      </span>
                      <span className="text-[11px] text-ink-muted">
                        {meta?.label ?? "—"}
                        {a.required ? " · bắt buộc" : " · tuỳ chọn"}
                      </span>
                    </span>
                  </button>
                  {!readOnly && (
                    <div className="flex items-center gap-1">
                      <Button
                        variant="secondary"
                        className="h-7 px-1.5"
                        disabled={i === 0}
                        onClick={() => onMoveActivity(a.id, -1)}
                        aria-label={`Chuyển hoạt động ${i + 1} lên`}
                      >
                        <ArrowUp className="size-3.5" />
                      </Button>
                      <Button
                        variant="secondary"
                        className="h-7 px-1.5"
                        disabled={i === stage.activities.length - 1}
                        onClick={() => onMoveActivity(a.id, 1)}
                        aria-label={`Chuyển hoạt động ${i + 1} xuống`}
                      >
                        <ArrowDown className="size-3.5" />
                      </Button>
                      {confirmActId === a.id ? (
                        <>
                          <Button
                            variant="secondary"
                            className="h-7 px-2 text-xs text-error"
                            onClick={() => {
                              onRemoveActivity(a.id);
                              setConfirmActId(null);
                            }}
                          >
                            Xoá
                          </Button>
                          <Button
                            variant="secondary"
                            className="h-7 px-2 text-xs"
                            onClick={() => setConfirmActId(null)}
                          >
                            Giữ
                          </Button>
                        </>
                      ) : (
                        <Button
                          variant="secondary"
                          className="h-7 px-1.5 text-error"
                          onClick={() => setConfirmActId(a.id)}
                          aria-label={`Xoá hoạt động ${i + 1}`}
                        >
                          <Trash2 className="size-3.5" />
                        </Button>
                      )}
                    </div>
                  )}
                </div>
              </li>
            );
          })}
        </ol>
        {stage.activities.length === 0 && !picking && (
          <p className="rounded-md border border-dashed border-border p-3 text-center text-xs text-ink-muted">
            Chưa có hoạt động — bấm &quot;Thêm hoạt động&quot; để bắt đầu.
          </p>
        )}
      </div>

      {/* Selected activity editor */}
      {selectedActivity && (
        <ActivityEditor
          key={selectedActivity.id}
          stage={stage}
          activity={selectedActivity}
          eventId={eventId}
          draft={draft}
          readOnly={readOnly}
          onChange={(patch) => onUpdateActivity(selectedActivity.id, patch)}
        />
      )}
    </div>
  );
}
