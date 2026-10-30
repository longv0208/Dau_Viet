"use client";

import { AlertTriangle, CheckCircle2, Info } from "lucide-react";
import type { PathAudit, PathDetail } from "@/lib/dto/learning-path";
import { cn } from "@/lib/utils";

export function PathValidation({
  report,
  detail,
  onSelect,
  onSelectTarget,
}: {
  report: PathAudit;
  detail: PathDetail;
  onSelect: (chapterId: string, eventNodeId?: string) => void;
  onSelectTarget?: (targetId: string) => void;
}) {
  const errors = report.issues.filter((issue) => issue.level === "ERROR");
  const warnings = report.issues.filter((issue) => issue.level === "WARNING");
  return (
    <section aria-label="Kết quả kiểm tra lộ trình" className="space-y-3">
      <p
        role="status"
        className={cn(
          "flex items-center gap-2 text-sm font-medium",
          errors.length ? "text-error" : "text-ink",
        )}
      >
        {errors.length ? (
          <AlertTriangle className="size-4" aria-hidden />
        ) : (
          <CheckCircle2 className="size-4" aria-hidden />
        )}
        {errors.length} lỗi chặn xuất bản · {warnings.length} cảnh báo
      </p>
      {report.issues.length === 0 && (
        <p className="text-sm text-ink-muted">
          Lộ trình đáp ứng điều kiện xuất bản.
        </p>
      )}
      <ul className="space-y-2">
        {report.issues.map((issue, index) => {
          const targetId = issue.targetId?.trim() || null;
          const chapter = targetId
            ? detail.chapters.find(
                (row) =>
                  row.chapter.id === targetId ||
                  row.events.some(
                    (event) =>
                      event.node.id === targetId ||
                      event.node.eventId === targetId ||
                      event.canonicalEventId === targetId ||
                      event.lessons.some(
                        (lesson) =>
                          lesson.node.id === targetId ||
                          lesson.node.lessonId === targetId,
                      ),
                  ),
              )
            : undefined;
          const event = chapter?.events.find(
            (row) =>
              row.node.id === targetId ||
              row.node.eventId === targetId ||
              row.canonicalEventId === targetId ||
              row.lessons.some(
                (lesson) =>
                  lesson.node.id === targetId ||
                  lesson.node.lessonId === targetId,
              ),
          );
          const Icon = issue.level === "ERROR" ? AlertTriangle : Info;
          return (
            <li
              key={`${issue.code}-${issue.targetId}-${index}`}
              className={cn(
                "rounded-lg border p-3 text-sm",
                issue.level === "ERROR"
                  ? "border-error/30 bg-error/5"
                  : "border-border bg-surface",
              )}
            >
              <div className="flex items-start gap-2">
                <Icon className="mt-0.5 size-4 shrink-0" aria-hidden />
                <div className="min-w-0">
                  <span className="font-semibold">
                    {issue.level === "ERROR"
                      ? "Lỗi"
                      : issue.level === "WARNING"
                        ? "Cảnh báo"
                        : "Thông tin"}
                  </span>
                  <p className="mt-1 break-words">{issue.message}</p>
                  {onSelectTarget && targetId && chapter ? (
                    <button
                      type="button"
                      title={event?.title ?? chapter?.chapter.title ?? undefined}
                      className="mt-2 text-xs font-medium text-brand underline"
                      onClick={() => onSelectTarget(targetId)}
                    >
                      Đi tới mục này →
                    </button>
                  ) : chapter ? (
                    <button
                      type="button"
                      className="mt-2 text-xs text-brand underline"
                      onClick={() =>
                        onSelect(chapter.chapter.id, event?.node.id)
                      }
                    >
                      Đi tới {event?.title ?? chapter.chapter.title}
                    </button>
                  ) : null}
                </div>
              </div>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
