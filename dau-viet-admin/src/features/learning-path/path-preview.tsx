"use client";

import { BookOpen, CheckCircle2, Compass, Flag } from "lucide-react";
import type { PathDetail } from "@/lib/dto/learning-path";
import { CONTENT_LABELS, historicalYear } from "./builder-types";

export function PathPreview({ detail, onSelect }: {
  detail: PathDetail; onSelect?: (chapterId: string, eventNodeId?: string) => void;
}) {
  return <div className="space-y-6 p-4" aria-label="Xem trước hành trình">
    <div><p className="text-xs font-semibold uppercase tracking-widest text-brand">Hành trình Dấu Việt</p><h2 className="mt-1 font-display text-xl font-semibold">{detail.version.title}</h2><p className="mt-1 text-xs text-ink-muted">Phiên bản {detail.version.versionNo} · Dữ liệu quản trị thực tế</p></div>
    {detail.chapters.length === 0 && <p className="text-sm text-ink-muted">Thêm chương để xem hành trình.</p>}
    {detail.chapters.map((row) => <section key={row.chapter.id} className="space-y-3">
      <button type="button" disabled={!onSelect} onClick={() => onSelect?.(row.chapter.id)} className="w-full rounded-lg bg-brand px-4 py-3 text-left text-white disabled:cursor-default">
        <span className="text-xs uppercase tracking-wider">Chương {row.chapter.sortOrder}</span><span className="mt-1 block font-display font-semibold">{row.chapter.title}</span><span className="mt-1 block text-xs opacity-90">{row.chapter.periodLabel}</span>
      </button>
      {row.events.length === 0 && <p className="pl-4 text-xs text-ink-muted">Chưa có sự kiện trong chương.</p>}
      <ol className="ml-5 space-y-4 border-l-2 border-border pb-3 pl-5">
        {row.events.map((event) => {
          const required = event.node.participationType === "REQUIRED";
          const Icon = required ? Flag : Compass;
          return <li key={event.node.id} className="relative">
            <span className="absolute -left-[27px] top-5 size-3 rounded-full border-2 border-surface bg-brand" aria-hidden />
            <button type="button" disabled={!onSelect} onClick={() => onSelect?.(row.chapter.id, event.node.id)} className="w-full rounded-lg border border-border bg-white p-3 text-left shadow-sm disabled:cursor-default enabled:hover:border-brand/50">
              <span className="text-xs font-semibold text-brand">{historicalYear(event.startYear)}</span>
              <span className="mt-1 block text-sm font-semibold">{event.title ?? "Sự kiện không còn tồn tại"}</span>
              <span className="mt-2 flex items-center gap-1 text-xs text-ink-muted"><Icon className="size-3.5" aria-hidden />{required ? "Bắt buộc" : "Tham khảo"}</span>
              <span className="mt-1 flex items-center gap-1 text-xs text-ink-muted"><BookOpen className="size-3.5" aria-hidden />{event.lessons.length} bài học</span>
              <span className="mt-2 flex items-start gap-1 text-xs text-ink-muted">{event.contentStatus === "PLAYABLE" && <CheckCircle2 className="size-3.5 shrink-0" aria-hidden />}{CONTENT_LABELS[event.contentStatus]}</span>
            </button>
          </li>;
        })}
      </ol>
    </section>)}
  </div>;
}
