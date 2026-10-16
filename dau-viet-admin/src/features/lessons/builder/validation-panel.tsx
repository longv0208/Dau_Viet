"use client";

import { AlertCircle } from "lucide-react";

import type { Draft } from "./draft-model";
import type { FieldError } from "./use-builder";

interface Props {
  draft: Draft;
  errors: FieldError[];
  onJump: (stageId: string | null, activityId: string | null) => void;
}

const STAGE_INDEX = /stages\[(\d+)\]/;
const STAGE_BY_ID = /stages\[id=([^\]]+)\]/;
const ACT_INDEX = /activities\[(\d+)\]/;

/** Resolve a server error path to (stageId, activityId) for click-to-jump. */
export function resolveErrorPath(
  draft: Draft,
  path: string,
): { stageId: string | null; activityId: string | null } {
  let stageId: string | null = null;
  const byId = STAGE_BY_ID.exec(path);
  if (byId) {
    stageId = draft.stages.find((s) => s.id === byId[1])?.id ?? null;
  } else {
    const byIdx = STAGE_INDEX.exec(path);
    if (byIdx) stageId = draft.stages[Number(byIdx[1])]?.id ?? null;
  }
  if (!stageId) return { stageId: null, activityId: null };
  const stage = draft.stages.find((s) => s.id === stageId);
  const actIdx = ACT_INDEX.exec(path);
  const activityId =
    stage && actIdx ? (stage.activities[Number(actIdx[1])]?.id ?? null) : null;
  return { stageId, activityId };
}

/** Right-pane list of server-side DRAFT_SCHEMA_INVALID errors. */
export function ValidationPanel({ draft, errors, onJump }: Props) {
  if (errors.length === 0) return null;
  return (
    <section
      aria-label="Lỗi lưu bản nháp"
      className="flex flex-col gap-2 rounded-md border border-error/40 bg-error/5 p-3"
    >
      <h4 className="flex items-center gap-1.5 text-sm font-semibold text-error">
        <AlertCircle className="size-4" aria-hidden /> Lỗi từ máy chủ ({errors.length})
      </h4>
      <ul className="flex flex-col gap-1">
        {errors.map((e, i) => {
          const target = resolveErrorPath(draft, e.path);
          return (
            <li key={`${e.path}-${i}`}>
              <button
                type="button"
                onClick={() => onJump(target.stageId, target.activityId)}
                className="w-full rounded px-2 py-1 text-left text-xs text-ink hover:bg-error/10"
              >
                <span className="block font-mono text-[10px] text-ink-muted">{e.path}</span>
                <span className="font-medium text-error">{e.code}</span> — {e.message}
              </button>
            </li>
          );
        })}
      </ul>
      <p className="text-[11px] text-ink-muted">
        Bấm vào lỗi để chuyển tới giai đoạn/hoạt động tương ứng.
      </p>
    </section>
  );
}
