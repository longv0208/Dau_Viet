"use client";

import { ChevronLeft, ChevronRight } from "lucide-react";

import type { Stage } from "../builder/draft-model";
import { Button } from "@/components/ui/button";

import { ActivityRenderer, activityLabel } from "./activity-renderer";
import type { EmbeddedAsset, EmbeddedEvidence } from "./renderers/types";
import { stageLabel } from "./stage-nav";

/**
 * Renders one stage of the projection: header + the currently selected
 * activity with prev/next navigation across the stage's activities.
 * The renderer subtree is keyed by activity id so interactive local state
 * (picks, orders, drafts) resets when switching between same-type activities.
 */
export function StageView({
  stage,
  activityIndex,
  onActivityChange,
  evidence,
  assets,
}: {
  stage: Stage;
  activityIndex: number;
  onActivityChange: (index: number) => void;
  evidence?: EmbeddedEvidence[];
  assets?: EmbeddedAsset[];
}) {
  const activities = stage.activities ?? [];
  const clamped = Math.min(Math.max(activityIndex, 0), Math.max(activities.length - 1, 0));
  const activity = activities[clamped] ?? null;

  return (
    <div className="flex flex-col gap-4">
      <header className="flex flex-col gap-0.5">
        <p className="text-[11px] font-medium uppercase tracking-wide text-ink-muted">
          {stageLabel(stage.type)}
          {stage.required === false ? " · không bắt buộc" : ""}
        </p>
        <h3 className="text-base font-semibold text-ink">
          {stage.title || stageLabel(stage.type)}
        </h3>
        {stage.description && (
          <p className="text-xs text-ink-muted">{stage.description}</p>
        )}
      </header>

      {activity ? (
        <div className="flex flex-col gap-3">
          <div className="flex items-center justify-between gap-2">
            <p className="text-xs font-medium text-ink-muted">
              Hoạt động {clamped + 1}/{activities.length} · {activityLabel(activity.type)}
            </p>
            <div className="flex gap-1">
              <Button
                variant="secondary"
                className="h-7 w-7 p-0"
                aria-label="Hoạt động trước"
                disabled={clamped === 0}
                onClick={() => onActivityChange(clamped - 1)}
              >
                <ChevronLeft className="size-4" />
              </Button>
              <Button
                variant="secondary"
                className="h-7 w-7 p-0"
                aria-label="Hoạt động tiếp"
                disabled={clamped >= activities.length - 1}
                onClick={() => onActivityChange(clamped + 1)}
              >
                <ChevronRight className="size-4" />
              </Button>
            </div>
          </div>

          {activity.instruction && (
            <p className="rounded-md bg-brand/5 px-3 py-2 text-sm font-medium text-ink">
              {activity.instruction}
            </p>
          )}

          {/* key={activity.id}: remount resets local state across activities. */}
          <ActivityRenderer
            key={activity.id}
            activity={activity}
            evidence={evidence}
            assets={assets}
          />

          {/* Numbered chips for direct activity navigation. */}
          {activities.length > 1 && (
            <div className="flex flex-wrap gap-1.5 pt-1">
              {activities.map((a, i) => (
                <button
                  key={a.id}
                  type="button"
                  aria-label={`Tới hoạt động ${i + 1}`}
                  aria-current={i === clamped}
                  onClick={() => onActivityChange(i)}
                  className={
                    "size-6 rounded-full text-[11px] font-medium " +
                    (i === clamped
                      ? "bg-brand text-white"
                      : "bg-surface-alt text-ink hover:bg-surface")
                  }
                >
                  {i + 1}
                </button>
              ))}
            </div>
          )}
        </div>
      ) : (
        <p className="py-8 text-center text-sm italic text-ink-muted">
          Giai đoạn chưa có hoạt động nào.
        </p>
      )}
    </div>
  );
}
