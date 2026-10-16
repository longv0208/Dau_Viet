"use client";

import { useMemo, useReducer } from "react";

import { genSlugId } from "./draft-id";
import {
  allIds,
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
}

export interface BuilderState {
  draft: Draft;
  dirty: boolean;
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
  | { type: "addActivity"; stageId: string; activity: Activity }
  | { type: "updateActivity"; stageId: string; activityId: string; patch: Partial<Activity> }
  | { type: "removeActivity"; stageId: string; activityId: string }
  | { type: "moveActivity"; stageId: string; activityId: string; dir: -1 | 1 }
  | { type: "setCompletion"; completion: Draft["completion"] }
  | { type: "setErrors"; errors: FieldError[] }
  | { type: "markSaved"; rowVersion: number }
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
        draft: mapStage(state.draft, a.id, (s) => ({ ...s, ...a.patch })),
      };
    case "addStage":
      return {
        ...state,
        dirty: true,
        draft: { ...state.draft, stages: [...state.draft.stages, a.stage] },
        selectedStageId: a.stage.id,
        selectedActivityId: null,
      };
    case "removeStage": {
      const draft = withoutStage(state.draft, a.id);
      return {
        ...state,
        dirty: true,
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
      return { ...state, dirty: true, draft: { ...state.draft, stages } };
    }
    case "duplicateStage": {
      const i = state.draft.stages.findIndex((s) => s.id === a.id);
      if (i < 0) return state;
      const src = state.draft.stages[i]!;
      const ids = allIds(state.draft);
      const copyId = genSlugId("stage", ids);
      const taken = [...ids, copyId];
      const copy: Stage = {
        ...src,
        id: copyId,
        title: src.title ? `${src.title} (bản sao)` : undefined,
        activities: src.activities.map((act) => {
          const id = genSlugId("act", taken);
          taken.push(id);
          return { ...act, id };
        }),
      };
      const stages = [...state.draft.stages];
      stages.splice(i + 1, 0, copy);
      return { ...state, dirty: true, draft: { ...state.draft, stages } };
    }
    case "mergeStages":
      return {
        ...state,
        dirty: true,
        draft: { ...state.draft, stages: [...state.draft.stages, ...a.stages] },
      };
    case "addActivity":
      return {
        ...state,
        dirty: true,
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
      return { ...state, dirty: true, draft: { ...state.draft, completion: a.completion } };
    case "setErrors":
      return { ...state, serverErrors: a.errors };
    case "markSaved":
      return {
        ...state,
        dirty: false,
        rowVersion: a.rowVersion,
        lastSavedAt: new Date().toISOString(),
        serverErrors: [],
      };
    case "setDraft":
      return {
        ...state,
        draft: a.draft,
        rowVersion: a.rowVersion,
        dirty: false,
        serverErrors: [],
      };
  }
}

export function makeActivity(type: ActivityType, existing: string[]): Activity {
  return { id: genSlugId("act", existing), type, required: false, instruction: "", config: {} };
}

export function makeStage(type: StageType, existing: string[], title?: string): Stage {
  return { id: genSlugId("stage", existing), type, title, required: true, activities: [] };
}

export function useBuilder(initial: Draft, rowVersion: number) {
  const [state, dispatch] = useReducer(reducer, {
    draft: initial,
    dirty: false,
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
      markSaved: (rowVersion: number) => dispatch({ type: "markSaved", rowVersion }),
      setDraft: (draft: Draft, rv: number) => dispatch({ type: "setDraft", draft, rowVersion: rv }),
    }),
    [],
  );

  return { state, actions, selectedStage, selectedActivity };
}
