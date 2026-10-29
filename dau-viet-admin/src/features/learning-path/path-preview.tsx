"use client";

import { BookOpen, CheckCircle2, Compass, Flag, GitBranch, Landmark } from "lucide-react";
import { SectionEyebrow } from "@/components/atoms/section-eyebrow";
import type { PathDetail } from "@/lib/dto/learning-path";
import { cn } from "@/lib/utils";
import {
  buildChapterTree,
  type ChapterTreeNode,
  CONTENT_LABELS,
  historicalYear,
  NODE_TYPE_META,
} from "./builder-types";

export function PathPreview({
  detail,
  onSelect,
}: {
  detail: PathDetail;
  onSelect?: (chapterId: string, eventNodeId?: string) => void;
}) {
  const roots = buildChapterTree(detail.chapters);

  const renderNode = (node: ChapterTreeNode) => {
    const { row, nodeType, children } = node;
    const meta = NODE_TYPE_META[nodeType];
    const NodeIcon =
      nodeType === "ERA" ? Landmark : nodeType === "PERIOD" ? Compass : GitBranch;

    return (
      <section
        key={row.chapter.id}
        className={cn(
          "space-y-3",
          nodeType === "PERIOD" && row.chapter.parentId && "ml-3 border-l-2 border-warning/50 pl-3",
          nodeType === "PHASE" && "ml-4 border-l-2 border-border pl-3",
        )}
      >
        <button
          type="button"
          disabled={!onSelect}
          onClick={() => onSelect?.(row.chapter.id)}
          className={cn(
            "w-full rounded-lg px-4 py-3 text-left transition-colors duration-150 disabled:cursor-default enabled:cursor-pointer",
            nodeType === "ERA"
              ? "bg-brand text-white shadow-sm enabled:hover:bg-brand-press"
              : nodeType === "PERIOD"
                ? "border border-warning/60 bg-surface-alt text-ink enabled:hover:border-brand/50"
                : "border border-border bg-surface-alt text-ink enabled:hover:border-brand/50",
          )}
        >
          <span className="inline-flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wider">
            <NodeIcon className="size-3.5" aria-hidden />
            {meta.shortLabel} {row.chapter.sortOrder}
          </span>
          <span className="mt-1 block font-display font-semibold">{row.chapter.title}</span>
          <span className="mt-1 block text-xs opacity-85">{row.chapter.periodLabel}</span>
        </button>

        {nodeType !== "ERA" && row.events.length === 0 && children.length === 0 && (
          <p className="pl-4 text-xs text-ink-muted">Chưa có sự kiện trong đơn vị này.</p>
        )}

        {row.events.length > 0 && (
          <ol className="ml-5 space-y-3 border-l-2 border-border pb-2 pl-5">
            {row.events.map((event) => {
              const required = event.node.participationType === "REQUIRED";
              const Icon = required ? Flag : Compass;
              return (
                <li key={event.node.id} className="relative">
                  <span
                    className="absolute -left-[27px] top-5 size-3 rounded-full border-2 border-surface bg-brand"
                    aria-hidden
                  />
                  <button
                    type="button"
                    disabled={!onSelect}
                    onClick={() => onSelect?.(row.chapter.id, event.node.id)}
                    className="w-full rounded-lg border border-border bg-surface-alt p-3 text-left shadow-heritage transition-colors duration-150 disabled:cursor-default enabled:cursor-pointer enabled:hover:border-brand/50"
                  >
                    <span className="text-xs font-semibold text-brand">
                      {historicalYear(event.startYear)}
                    </span>
                    <span className="mt-1 block text-sm font-semibold">
                      {event.title ?? "Sự kiện không còn tồn tại"}
                    </span>
                    <span className="mt-2 flex items-center gap-1 text-xs text-ink-muted">
                      <Icon className="size-3.5" aria-hidden />
                      {required ? "Bắt buộc" : "Tham khảo"}
                    </span>
                    <span className="mt-1 flex items-center gap-1 text-xs text-ink-muted">
                      <BookOpen className="size-3.5" aria-hidden />
                      {event.lessons.length} bài học
                    </span>
                    <span className="mt-2 flex items-start gap-1 text-xs text-ink-muted">
                      {event.contentStatus === "PLAYABLE" && (
                        <CheckCircle2 className="size-3.5 shrink-0 text-success" aria-hidden />
                      )}
                      {CONTENT_LABELS[event.contentStatus]}
                    </span>
                  </button>
                </li>
              );
            })}
          </ol>
        )}

        {children.length > 0 && (
          <div className="space-y-3">{children.map((child) => renderNode(child))}</div>
        )}
      </section>
    );
  };

  return (
    <div className="space-y-6 p-4" aria-label="Xem trước hành trình">
      <div>
        <SectionEyebrow color="brand">Hành trình Dấu Việt</SectionEyebrow>
        <h2 className="mt-2 font-display text-xl font-semibold text-ink">{detail.version.title}</h2>
        <p className="mt-1 text-xs text-ink-muted">
          Phiên bản {detail.version.versionNo} · Cấu trúc cây phân cấp thực tế
        </p>
      </div>
      {roots.length === 0 && (
        <p className="text-sm text-ink-muted">Thêm Đại thời kỳ hoặc Thời kỳ để xem hành trình.</p>
      )}
      {roots.map((root) => renderNode(root))}
    </div>
  );
}
