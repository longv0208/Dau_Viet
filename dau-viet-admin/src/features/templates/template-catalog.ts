/**
 * Stage/activity catalogue for the template designer.
 * Built from the backend contract mirrors in draft-model + labels —
 * do NOT add activity types the backend doesn't allow.
 */
import {
  ACTIVITY_TYPES,
  STAGE_ALLOWED_ACTIVITIES,
  STAGE_TYPES,
  defaultFeedbackForActivity,
  withDefaultFeedback,
  type Activity,
  type ActivityType,
  type Draft,
  type Stage,
  type StageType,
} from "@/features/lessons/builder/draft-model";
import { genSlugId } from "@/features/lessons/builder/draft-id";

export { STAGE_TYPES, STAGE_ALLOWED_ACTIVITIES };
export type { Activity, ActivityType, Draft, Stage, StageType };

/** Activity types that write free-text answers — auto-grading is not
 * reliable yet, so the catalogue flags them for the admin. */
export const OPEN_ENDED_ACTIVITIES: ReadonlySet<ActivityType> = new Set<ActivityType>([
  "CER",
  "REFLECTION_PROMPT",
]);

/** Detect a preset whose stage graph is not a simple linear chain —
 * branchy presets stay read-only in this editor so edits can't silently
 * flatten a deliberate graph. */
export function isNonLinearDraft(draft: Draft): boolean {
  const stages = draft.stages;
  for (let i = 0; i < stages.length; i++) {
    const next = stages[i]!.nextStageIds ?? [];
    if (next.length > 1) return true;
    if (next.length === 1 && next[0] !== stages[i + 1]?.id) return true;
    if (next.length === 0 && i < stages.length - 1) {
      // A stage that doesn't lead anywhere while more stages follow —
      // the linear editor can't represent it faithfully.
      return true;
    }
  }
  return false;
}

/** Rebuild nextStageIds as a linear chain following array order. */
export function linearize(stages: Stage[]): Stage[] {
  return stages.map((s, i) => ({
    ...s,
    nextStageIds: i < stages.length - 1 ? [stages[i + 1]!.id] : [],
  }));
}

export function makeTemplateStage(type: StageType, existingIds: string[]): Stage {
  return {
    id: genSlugId(`stage-${type.toLowerCase()}`, existingIds),
    type,
    title: "",
    required: true,
    activities: [],
    nextStageIds: [],
  };
}

export function makeTemplateActivity(type: ActivityType, existingIds: string[]): Activity {
  return {
    id: genSlugId("act", existingIds),
    type,
    required: true,
    instruction: "",
    config: type === "EVIDENCE_SELECT" ? { graded: true } : {},
    feedback: defaultFeedbackForActivity(type),
  };
}

/** Serialize the working stage list back to a presetJson skeleton —
 * keeps activities (unlike the legacy form) and rebuilds linear links. */
export function buildPresetJson(stages: Stage[]): string {
  return JSON.stringify({
    schemaVersion: 1,
    stages: linearize(stages).map((s) => ({
      id: s.id,
      type: s.type,
      title: (s.title ?? "").trim(),
      required: true,
      activities: s.activities.map((a) => ({
        ...a,
        required: true,
        ...(a.type === "EVIDENCE_SELECT"
          ? { config: { ...(a.config ?? {}), graded: true } }
          : {}),
        feedback: withDefaultFeedback(a.type, a.feedback),
      })),
      nextStageIds: s.nextStageIds ?? [],
    })),
  });
}

/** All activity ids in the current stage list — for genSlugId uniqueness. */
export function allWorkingIds(stages: Stage[]): string[] {
  const ids: string[] = [];
  for (const s of stages) {
    ids.push(s.id);
    for (const a of s.activities) ids.push(a.id);
  }
  return ids;
}

/** Filter predicate for the library search box — a stage card stays
 * visible when its own label/description matches or any allowed
 * activity does. */
export function stageMatches(
  stageType: StageType,
  q: string,
  stageLabel: { label: string; description: string },
  activityLabel: (t: ActivityType) => { label: string; description: string },
): boolean {
  if (!q) return true;
  const needle = q.toLowerCase();
  if (
    stageLabel.label.toLowerCase().includes(needle) ||
    stageLabel.description.toLowerCase().includes(needle) ||
    stageType.toLowerCase().includes(needle)
  ) {
    return true;
  }
  return (STAGE_ALLOWED_ACTIVITIES[stageType] ?? []).some((t) => {
    const meta = activityLabel(t);
    return (
      meta.label.toLowerCase().includes(needle) ||
      meta.description.toLowerCase().includes(needle) ||
      t.toLowerCase().includes(needle)
    );
  });
}

/** Quick sanity list — every declared activity type must appear in at
 * least one stage's allowed set (guards against catalogue drift). */
export const CATALOGUE_COVERED: ReadonlySet<ActivityType> = new Set(
  STAGE_TYPES.flatMap((s) => STAGE_ALLOWED_ACTIVITIES[s] ?? []),
);
export const ALL_ACTIVITIES_COVERED = ACTIVITY_TYPES.every((t) => CATALOGUE_COVERED.has(t));
