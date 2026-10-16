/**
 * Typed model for the backend `draftJson` document (DraftSchema.java).
 * Round-trip rule: every object keeps unknown keys via `...rest` — the
 * builder never silently drops fields it doesn't model.
 *
 * Verified against DraftSchema.java (see plans/reports/planner-261017-0531-…).
 */

export const STAGE_TYPES = [
  "CONTEXT",
  "DISCOVERY",
  "EVIDENCE",
  "REASONING",
  "HYPOTHESIS",
  "RECONSTRUCTION",
  "VERIFICATION",
  "CONCLUSION",
  "REFLECTION",
] as const;
export type StageType = (typeof STAGE_TYPES)[number];

export const ACTIVITY_TYPES = [
  "READ",
  "VIEW_IMAGE",
  "MULTIPLE_CHOICE",
  "EXPLORE_MAP",
  "EVIDENCE_SELECT",
  "MATCHING",
  "REASONING_CONNECT",
  "HYPOTHESIS_CHOICE",
  "DRAG_ORDER",
  "VERIFICATION",
  "CER",
  "REFLECTION_PROMPT",
] as const;
export type ActivityType = (typeof ACTIVITY_TYPES)[number];

/** Mirrors DraftSchema.STAGE_ALLOWED_ACTIVITIES — READ is universal. */
export const STAGE_ALLOWED_ACTIVITIES: Record<StageType, ActivityType[]> = {
  CONTEXT: ["READ", "VIEW_IMAGE"],
  DISCOVERY: ["EXPLORE_MAP", "VIEW_IMAGE", "READ"],
  EVIDENCE: ["EVIDENCE_SELECT", "MULTIPLE_CHOICE", "READ"],
  REASONING: ["MATCHING", "REASONING_CONNECT", "MULTIPLE_CHOICE", "READ"],
  HYPOTHESIS: ["HYPOTHESIS_CHOICE", "READ"],
  RECONSTRUCTION: ["DRAG_ORDER", "READ"],
  VERIFICATION: ["VERIFICATION", "MULTIPLE_CHOICE", "READ"],
  CONCLUSION: ["CER", "READ"],
  REFLECTION: ["REFLECTION_PROMPT", "READ"],
};

export interface Activity {
  id: string;
  type: ActivityType;
  required?: boolean;
  instruction?: string;
  config?: Record<string, unknown>;
  validation?: Record<string, unknown>;
  feedback?: Record<string, unknown>;
  evidenceRefs?: string[];
  [key: string]: unknown;
}

export interface Stage {
  id: string;
  type: StageType;
  title?: string;
  required?: boolean;
  activities: Activity[];
  nextStageIds?: string[];
  requiredEvidenceIds?: string[];
  [key: string]: unknown;
}

export interface Completion {
  requireAllRequiredStages?: boolean;
  requiredStageIds?: string[];
  minScore?: number;
  [key: string]: unknown;
}

export interface Draft {
  schemaVersion?: number;
  stages: Stage[];
  completion?: Completion;
  objectives?: unknown;
  [key: string]: unknown;
}

export class DraftParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DraftParseError";
  }
}

/** Tolerant parse: "{}" / "" / missing → empty draft; non-object → throws. */
export function parseDraft(json: string | null | undefined): Draft {
  const raw = (json ?? "").trim() || "{}";
  let obj: unknown;
  try {
    obj = JSON.parse(raw);
  } catch {
    throw new DraftParseError("Bản nháp không phải JSON hợp lệ");
  }
  if (typeof obj !== "object" || obj === null || Array.isArray(obj)) {
    throw new DraftParseError("Bản nháp phải là một JSON object");
  }
  const src = obj as Record<string, unknown>;
  const stages: Stage[] = Array.isArray(src.stages)
    ? src.stages
        .filter((s) => s && typeof s === "object")
        .map((s) => {
          const st = s as Record<string, unknown>;
          return {
            ...st,
            id: String(st.id ?? ""),
            type: st.type as StageType,
            activities: Array.isArray(st.activities)
              ? st.activities
                  .filter((a) => a && typeof a === "object")
                  .map((a) => ({ ...(a as object) }) as Activity)
              : [],
          } as Stage;
        })
    : [];
  const draft: Draft = { ...src, stages };
  if (draft.schemaVersion === undefined) draft.schemaVersion = 1;
  return draft;
}

/** Serialize back — preserves every key parseDraft kept. */
export function serializeDraft(draft: Draft): string {
  return JSON.stringify(draft);
}

/** Every id in the document — used by genSlugId uniqueness checks. */
export function allIds(draft: Draft): string[] {
  const ids: string[] = [];
  for (const s of draft.stages) {
    ids.push(s.id);
    for (const a of s.activities) ids.push(a.id);
  }
  return ids;
}
