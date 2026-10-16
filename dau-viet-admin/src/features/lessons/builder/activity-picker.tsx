"use client";

import type { ActivityType, StageType } from "./draft-model";
import { STAGE_ALLOWED_ACTIVITIES } from "./draft-model";
import { ACTIVITY_LABELS } from "./labels";

interface Props {
  stageType: StageType;
  onPick: (type: ActivityType) => void;
}

/** Grid of activity types allowed for the current stage type. */
export function ActivityPicker({ stageType, onPick }: Props) {
  const allowed = STAGE_ALLOWED_ACTIVITIES[stageType] ?? ["READ"];
  return (
    <div className="grid gap-2 sm:grid-cols-2">
      {allowed.map((t) => {
        const meta = ACTIVITY_LABELS[t];
        const Icon = meta.icon;
        return (
          <button
            key={t}
            type="button"
            onClick={() => onPick(t)}
            className="flex items-start gap-2.5 rounded-md border border-border bg-white p-3 text-left transition-colors hover:border-brand hover:bg-brand/5"
          >
            <Icon className="mt-0.5 size-5 shrink-0 text-brand" aria-hidden />
            <span>
              <span className="block text-sm font-medium text-ink">{meta.label}</span>
              <span className="mt-0.5 block text-xs text-ink-muted">{meta.description}</span>
            </span>
          </button>
        );
      })}
    </div>
  );
}
