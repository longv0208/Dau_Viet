"use client";

import { useMemo, useReducer } from "react";

import { genSlugId } from "./draft-id";
import {
  allIds,
  defaultFeedbackForActivity,
  type Activity,
  type ActivityType,
  type Draft,
  type Stage,
  type StageType,
} from "./draft-model";

export interface FieldError {
  path: string;
  code: string;
  message: string;
  /** FE-supplied detail text — ưu tiên `message` khi có. */
  detail?: string;
}

export interface BuilderState {
  draft: Draft;
  dirty: boolean;
  /** Monotonic counter, +1 on every draft mutation — used to detect edits during a pending save. */
  revision: number;
  /** Revision captured at the last successful save; dirty = revision !== savedRevision. */
  savedRevision: number;
  rowVersion: number;
  lastSavedAt: string | null;
  selectedStageId: string | null;
  selectedActivityId: string | null;
  serverErrors: FieldError[];
}

type Action =
  | { type: "selectStage"; id: string | null }
  | { type: "selectActivity"; id: string | null }
  | { type: "updateStage"; id: string; patch: Partial<Stage> }
  | { type: "addStage"; stage: Stage }
  | { type: "removeStage"; id: string }
  | { type: "moveStage"; id: string; dir: -1 | 1 }
  | { type: "duplicateStage"; id: string }
  | { type: "mergeStages"; stages: Stage[] }
  | { type: "replaceStages"; stages: Stage[] }
  | { type: "addActivity"; stageId: string; activity: Activity }
  | { type: "updateActivity"; stageId: string; activityId: string; patch: Partial<Activity> }
  | { type: "removeActivity"; stageId: string; activityId: string }
  | { type: "moveActivity"; stageId: string; activityId: string; dir: -1 | 1 }
  | { type: "setCompletion"; completion: Draft["completion"] }
  | { type: "setErrors"; errors: FieldError[] }
  | { type: "markSaved"; rowVersion: number; revision: number }
  | { type: "setDraft"; draft: Draft; rowVersion: number };

function mapStage(draft: Draft, id: string, fn: (s: Stage) => Stage): Draft {
  return { ...draft, stages: draft.stages.map((s) => (s.id === id ? fn(s) : s)) };
}

/** Removing a stage also prunes dangling nextStageIds + completion refs. */
function withoutStage(draft: Draft, id: string): Draft {
  const stages = draft.stages
    .filter((s) => s.id !== id)
    .map((s) =>
      s.nextStageIds?.includes(id)
        ? { ...s, nextStageIds: s.nextStageIds.filter((n) => n !== id) }
        : s,
    );
  const completion = draft.completion?.requiredStageIds?.includes(id)
    ? {
        ...draft.completion,
        requiredStageIds: draft.completion.requiredStageIds.filter((r) => r !== id),
      }
    : draft.completion;
  return { ...draft, stages, completion };
}

function reducer(state: BuilderState, a: Action): BuilderState {
  switch (a.type) {
    case "selectStage":
      return { ...state, selectedStageId: a.id, selectedActivityId: null };
    case "selectActivity":
      return { ...state, selectedActivityId: a.id };
    case "updateStage":
      return {
        ...state,
        dirty: true,
        revision: state.revision + 1,
        draft: mapStage(state.draft, a.id, (s) => ({ ...s, ...a.patch })),
      };
    case "addStage":
      return {
        ...state,
        dirty: true,
        revision: state.revision + 1,
        draft: { ...state.draft, stages: [...state.draft.stages, a.stage] },
        selectedStageId: a.stage.id,
        selectedActivityId: null,
      };
    case "removeStage": {
      const draft = withoutStage(state.draft, a.id);
      return {
        ...state,
        dirty: true,
        revision: state.revision + 1,
        draft,
        selectedStageId: state.selectedStageId === a.id ? null : state.selectedStageId,
        selectedActivityId:
          state.selectedStageId === a.id ? null : state.selectedActivityId,
      };
    }
    case "moveStage": {
      const i = state.draft.stages.findIndex((s) => s.id === a.id);
      const j = i + a.dir;
      if (i < 0 || j < 0 || j >= state.draft.stages.length) return state;
      const stages = [...state.draft.stages];
      [stages[i], stages[j]] = [stages[j]!, stages[i]!];
      return { ...state, dirty: true, revision: state.revision + 1, draft: { ...state.draft, stages } };
    }
    case "duplicateStage": {
      const i = state.draft.stages.findIndex((s) => s.id === a.id);
      if (i < 0) return state;
      const src = state.draft.stages[i]!;
      const ids = allIds(state.draft);
      const copyId = genSlugId("stage", ids);
      const taken = [...ids, copyId];
      // idMap remap nextStageIds nội bộ (trỏ vào chính stage nguồn) sang id mới.
      const idMap = new Map<string, string>([[src.id, copyId]]);
      const copy: Stage = {
        ...src,
        id: copyId,
        title: src.title ? `${src.title} (bản sao)` : undefined,
        activities: src.activities.map((act) => {
          const id = genSlugId("act", taken);
          taken.push(id);
          idMap.set(act.id, id);
          return { ...act, id };
        }),
      };
      if (Array.isArray(copy.nextStageIds)) {
        copy.nextStageIds = copy.nextStageIds.map((n) => idMap.get(n) ?? n);
      }
      const stages = [...state.draft.stages];
      stages.splice(i + 1, 0, copy);
      return { ...state, dirty: true, revision: state.revision + 1, draft: { ...state.draft, stages } };
    }
    case "mergeStages":
      return {
        ...state,
        dirty: true,
        revision: state.revision + 1,
        draft: { ...state.draft, stages: [...state.draft.stages, ...a.stages] },
      };
    case "replaceStages":
      return {
        ...state,
        dirty: true,
        revision: state.revision + 1,
        draft: { ...state.draft, stages: a.stages },
      };
    case "addActivity":
      return {
        ...state,
        dirty: true,
        revision: state.revision + 1,
        draft: mapStage(state.draft, a.stageId, (s) => ({
          ...s,
          activities: [...s.activities, a.activity],
        })),
        selectedActivityId: a.activity.id,
      };
    case "updateActivity":
      return {
        ...state,
        dirty: true,
        revision: state.revision + 1,
        draft: mapStage(state.draft, a.stageId, (s) => ({
          ...s,
          activities: s.activities.map((act) =>
            act.id === a.activityId ? { ...act, ...a.patch } : act,
          ),
        })),
      };
    case "removeActivity":
      return {
        ...state,
        dirty: true,
        revision: state.revision + 1,
        draft: mapStage(state.draft, a.stageId, (s) => ({
          ...s,
          activities: s.activities.filter((act) => act.id !== a.activityId),
        })),
        selectedActivityId:
          state.selectedActivityId === a.activityId ? null : state.selectedActivityId,
      };
    case "moveActivity":
      return {
        ...state,
        dirty: true,
        revision: state.revision + 1,
        draft: mapStage(state.draft, a.stageId, (s) => {
          const i = s.activities.findIndex((act) => act.id === a.activityId);
          const j = i + a.dir;
          if (i < 0 || j < 0 || j >= s.activities.length) return s;
          const activities = [...s.activities];
          [activities[i], activities[j]] = [activities[j]!, activities[i]!];
          return { ...s, activities };
        }),
      };
    case "setCompletion":
      return {
        ...state,
        dirty: true,
        revision: state.revision + 1,
        draft: { ...state.draft, completion: a.completion },
      };
    case "setErrors":
      return { ...state, serverErrors: a.errors };
    case "markSaved": {
      // Chỉ tắt dirty khi revision lúc bắt đầu lưu khớp revision hiện tại —
      // nếu người dùng sửa trong lúc PUT đang chạy, dirty vẫn giữ để lưu tiếp.
      const clean = a.revision === state.revision;
      return {
        ...state,
        dirty: !clean,
        savedRevision: a.revision,
        rowVersion: a.rowVersion,
        lastSavedAt: new Date().toISOString(),
        serverErrors: [],
      };
    }
    case "setDraft":
      return {
        ...state,
        draft: a.draft,
        rowVersion: a.rowVersion,
        dirty: false,
        revision: state.revision + 1,
        savedRevision: state.revision + 1,
        serverErrors: [],
      };
  }
}

export const DEFAULT_ACTIVITY_FEEDBACK: Record<string, string> = {
  COMPLETED: "Chính xác! Bạn đã hoàn thành bước điều tra này.",
  INCORRECT: "Chưa chính xác, hãy đối chiếu lại tư liệu và bằng chứng.",
  PARTIAL: "Bạn đã chọn đúng một phần, hãy kiểm tra lại các chi tiết còn thiếu.",
  EXHAUSTED: "Đã hết lượt thử. Hãy xem gợi ý chuẩn để tiếp tục hành trình.",
  SUPPORTED: "Giả thuyết hoàn toàn phù hợp với các bằng chứng đã thu thập.",
  CONTRADICTED: "Bằng chứng cho thấy giả thuyết này chưa chính xác, cần xem xét lại.",
};

export function makeActivity(type: ActivityType, existing: string[]): Activity {
  return {
    id: genSlugId("act", existing),
    type,
    required: true,
    instruction: "",
    config: type === "EVIDENCE_SELECT" ? { graded: true } : {},
    feedback: defaultFeedbackForActivity(type),
  };
}

export function makeStage(type: StageType, existing: string[], title?: string): Stage {
  return { id: genSlugId("stage", existing), type, title, required: true, activities: [] };
}

export function useBuilder(initial: Draft, rowVersion: number) {
  const [state, dispatch] = useReducer(reducer, {
    draft: initial,
    dirty: false,
    revision: 0,
    savedRevision: 0,
    rowVersion,
    lastSavedAt: null,
    selectedStageId: initial.stages[0]?.id ?? null,
    selectedActivityId: null,
    serverErrors: [],
  });

  const selectedStage = useMemo(
    () => state.draft.stages.find((s) => s.id === state.selectedStageId) ?? null,
    [state.draft.stages, state.selectedStageId],
  );
  const selectedActivity = useMemo(
    () => selectedStage?.activities.find((a) => a.id === state.selectedActivityId) ?? null,
    [selectedStage, state.selectedActivityId],
  );

  const actions = useMemo(
    () => ({
      selectStage: (id: string | null) => dispatch({ type: "selectStage", id }),
      selectActivity: (id: string | null) => dispatch({ type: "selectActivity", id }),
      updateStage: (id: string, patch: Partial<Stage>) =>
        dispatch({ type: "updateStage", id, patch }),
      addStage: (stage: Stage) => dispatch({ type: "addStage", stage }),
      removeStage: (id: string) => dispatch({ type: "removeStage", id }),
      moveStage: (id: string, dir: -1 | 1) => dispatch({ type: "moveStage", id, dir }),
      duplicateStage: (id: string) => dispatch({ type: "duplicateStage", id }),
      mergeStages: (stages: Stage[]) => dispatch({ type: "mergeStages", stages }),
      replaceStages: (stages: Stage[]) => dispatch({ type: "replaceStages", stages }),
      addActivity: (stageId: string, activity: Activity) =>
        dispatch({ type: "addActivity", stageId, activity }),
      updateActivity: (stageId: string, activityId: string, patch: Partial<Activity>) =>
        dispatch({ type: "updateActivity", stageId, activityId, patch }),
      removeActivity: (stageId: string, activityId: string) =>
        dispatch({ type: "removeActivity", stageId, activityId }),
      moveActivity: (stageId: string, activityId: string, dir: -1 | 1) =>
        dispatch({ type: "moveActivity", stageId, activityId, dir }),
      setCompletion: (completion: Draft["completion"]) =>
        dispatch({ type: "setCompletion", completion }),
      setErrors: (errors: FieldError[]) => dispatch({ type: "setErrors", errors }),
      markSaved: (rowVersion: number, revision: number) =>
        dispatch({ type: "markSaved", rowVersion, revision }),
      setDraft: (draft: Draft, rv: number) => dispatch({ type: "setDraft", draft, rowVersion: rv }),
    }),
    [],
  );

  return { state, actions, selectedStage, selectedActivity };
}
