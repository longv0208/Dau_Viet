"use client";

import { ArrowDown, ArrowUp, Copy, Plus, Trash2 } from "lucide-react";
import { useState } from "react";

import type { Draft, StageType } from "./draft-model";
import { STAGE_TYPES } from "./draft-model";
import { STAGE_LABELS } from "./labels";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";

interface Props {
  draft: Draft;
  selectedStageId: string | null;
  readOnly?: boolean;
  onSelect: (id: string) => void;
  onAdd: (type: StageType) => void;
  onMove: (id: string, dir: -1 | 1) => void;
  onDuplicate: (id: string) => void;
  onRemove: (id: string) => void;
}

/** Left pane — ordered stage list with add/reorder/duplicate/delete. */
export function StageNavigator({
  draft,
  selectedStageId,
  readOnly,
  onSelect,
  onAdd,
  onMove,
  onDuplicate,
  onRemove,
}: Props) {
  const [addType, setAddType] = useState<StageType>("CONTEXT");
  const [confirmId, setConfirmId] = useState<string | null>(null);

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-ink">Giai đoạn ({draft.stages.length})</h3>
      </div>

      <ol className="flex flex-col gap-1.5">
        {draft.stages.map((s, i) => {
          const meta = STAGE_LABELS[s.type];
          const Icon = meta?.icon;
          const selected = s.id === selectedStageId;
          return (
            <li key={s.id}>
              <div
                className={
                  "group rounded-md border p-2 transition-colors " +
                  (selected ? "border-brand bg-brand/5" : "border-border bg-white hover:bg-surface")
                }
              >
                <button
                  type="button"
                  onClick={() => onSelect(s.id)}
                  className="flex w-full items-start gap-2 text-left"
                >
                  {Icon && <Icon className="mt-0.5 size-4 shrink-0 text-ink-muted" aria-hidden />}
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-medium text-ink">
                      {i + 1}. {s.title || meta?.label || s.id}
                    </span>
                    <span className="mt-0.5 flex flex-wrap items-center gap-1.5 text-[11px] text-ink-muted">
                      <span>{meta?.label ?? s.type}</span>
                      <span aria-hidden>·</span>
                      <span>{s.activities.length} hoạt động</span>
                      {s.required ? (
                        <span className="rounded bg-brand/10 px-1 text-brand">bắt buộc</span>
                      ) : (
                        <span className="rounded bg-surface-alt px-1">tuỳ chọn</span>
                      )}
                    </span>
                  </span>
                </button>
                {!readOnly && (
                  <div className="mt-1.5 flex items-center gap-1 border-t border-border/60 pt-1.5 opacity-0 transition-opacity group-hover:opacity-100">
                    <Button
                      variant="secondary"
                      className="h-7 px-2 text-xs"
                      disabled={i === 0}
                      onClick={() => onMove(s.id, -1)}
                      aria-label={`Chuyển ${s.title || s.id} lên`}
                    >
                      <ArrowUp className="size-3.5" />
                    </Button>
                    <Button
                      variant="secondary"
                      className="h-7 px-2 text-xs"
                      disabled={i === draft.stages.length - 1}
                      onClick={() => onMove(s.id, 1)}
                      aria-label={`Chuyển ${s.title || s.id} xuống`}
                    >
                      <ArrowDown className="size-3.5" />
                    </Button>
                    <Button
                      variant="secondary"
                      className="h-7 px-2 text-xs"
                      onClick={() => onDuplicate(s.id)}
                      aria-label={`Nhân bản ${s.title || s.id}`}
                    >
                      <Copy className="size-3.5" />
                    </Button>
                    {confirmId === s.id ? (
                      <span className="ml-auto flex items-center gap-1">
                        <Button
                          variant="secondary"
                          className="h-7 px-2 text-xs text-error"
                          onClick={() => {
                            onRemove(s.id);
                            setConfirmId(null);
                          }}
                        >
                          Xoá
                        </Button>
                        <Button
                          variant="secondary"
                          className="h-7 px-2 text-xs"
                          onClick={() => setConfirmId(null)}
                        >
                          Giữ
                        </Button>
                      </span>
                    ) : (
                      <Button
                        variant="secondary"
                        className="ml-auto h-7 px-2 text-xs text-error"
                        onClick={() => setConfirmId(s.id)}
                        aria-label={`Xoá ${s.title || s.id}`}
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

      {draft.stages.length === 0 && (
        <p className="rounded-md border border-dashed border-border p-3 text-center text-xs text-ink-muted">
          Chưa có giai đoạn nào. Thêm giai đoạn đầu tiên bên dưới.
        </p>
      )}

      {!readOnly && (
        <div className="flex items-center gap-2">
          <Select
            value={addType}
            onChange={(e) => setAddType(e.target.value as StageType)}
            aria-label="Loại giai đoạn mới"
            className="flex-1"
          >
            {STAGE_TYPES.map((t) => (
              <option key={t} value={t}>
                {STAGE_LABELS[t].label}
              </option>
            ))}
          </Select>
          <Button variant="secondary" onClick={() => onAdd(addType)} aria-label="Thêm giai đoạn">
            <Plus className="size-4" />
          </Button>
        </div>
      )}
    </div>
  );
}
