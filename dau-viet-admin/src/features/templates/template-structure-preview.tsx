"use client";

/** Read-only structure preview of the template skeleton — shows the stage
 * order, each stage's activities with required/optional flags and the
 * linear nextStageIds flow. It is NOT a learner preview: the skeleton
 * intentionally has no authored content yet. */
import { X } from "lucide-react";

import { STAGE_LABELS, ACTIVITY_LABELS } from "@/features/lessons/builder/labels";
import { Button } from "@/components/ui/button";

import type { ActivityType, Stage } from "./template-catalog";

export function TemplateStructurePreview({
  stages,
  open,
  onClose,
}: {
  stages: Stage[];
  open: boolean;
  onClose: () => void;
}) {
  if (!open) return null;
  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Xem cấu trúc khung bài học"
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
    >
      <div className="flex max-h-[80vh] w-full max-w-lg flex-col rounded-lg bg-white shadow-lg">
        <header className="flex items-center justify-between border-b border-border px-4 py-3">
          <div>
            <h2 className="text-sm font-semibold text-ink">Cấu trúc khung</h2>
            <p className="text-xs text-ink-muted">
              {stages.length} giai đoạn ·{" "}
              {stages.reduce((n, s) => n + s.activities.length, 0)} hoạt động — bố cục học
              viên sẽ trải nghiệm (chưa gồm nội dung soạn sau).
            </p>
          </div>
          <Button type="button" variant="secondary" size="sm" onClick={onClose} aria-label="Đóng">
            <X className="size-4" aria-hidden />
          </Button>
        </header>
        <ol className="flex min-h-0 flex-1 flex-col gap-3 overflow-y-auto p-4">
          {stages.length === 0 && (
            <p className="py-8 text-center text-sm text-ink-muted">Khung chưa có giai đoạn nào.</p>
          )}
          {stages.map((s, i) => {
            const meta = STAGE_LABELS[s.type];
            const isLast = i === stages.length - 1;
            return (
              <li key={s.id} className="flex flex-col gap-1">
                <div className="flex items-center gap-2">
                  <span className="flex size-6 shrink-0 items-center justify-center rounded-full bg-brand/10 text-xs font-semibold text-brand">
                    {i + 1}
                  </span>
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-ink">
                      {s.title?.trim() || meta.label}
                      <span className="ml-2 text-xs font-normal text-ink-muted">
                        {meta.label}
                      </span>
                    </p>
                  </div>
                  {s.required === false && (
                    <span className="ml-auto rounded bg-surface-alt px-1.5 py-0.5 text-[10px] text-ink-muted">
                      Tuỳ chọn
                    </span>
                  )}
                </div>
                <ul className="ml-8 flex flex-col gap-0.5">
                  {s.activities.length === 0 && (
                    <li className="text-xs italic text-ink-muted">Chưa có hoạt động</li>
                  )}
                  {s.activities.map((a) => {
                    const aMeta = ACTIVITY_LABELS[a.type as ActivityType];
                    return (
                      <li key={a.id} className="flex items-center gap-2 text-xs text-ink">
                        <span aria-hidden>·</span>
                        <span>{aMeta?.label ?? a.type}</span>
                        <span className="text-ink-muted">
                          {a.required ? "bắt buộc" : "tuỳ chọn"}
                        </span>
                      </li>
                    );
                  })}
                </ul>
                {!isLast && (
                  <p className="ml-8 text-xs text-ink-muted" aria-hidden>
                    ↓ chuyển tiếp
                  </p>
                )}
              </li>
            );
          })}
        </ol>
      </div>
    </div>
  );
}
