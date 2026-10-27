"use client";

import Link from "next/link";
import { useState } from "react";
import { ArrowLeft, CheckCircle2, Eye, RefreshCw, Save } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Dialog } from "@/components/ui/dialog";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { ErrorState } from "@/components/error-state";
import { StatusChip } from "@/components/status-chip";
import { cn } from "@/lib/utils";
import { usePathEditor } from "./use-learning-path";
import { ChapterPanel } from "./chapter-panel";
import { EventPanel } from "./event-panel";
import { PathPreview } from "./path-preview";
import { PathValidation } from "./path-validation";
import type { PathChange } from "./builder-types";

type Panel = "chapters" | "events" | "preview";
const TABS: { key: Panel; label: string }[] = [{ key: "chapters", label: "Chương" }, { key: "events", label: "Sự kiện" }, { key: "preview", label: "Xem trước" }];

export function PathBuilder({ versionId }: { versionId: string }) {
  const editor = usePathEditor(versionId);
  const [chapterId, setChapterId] = useState<string>();
  const [eventId, setEventId] = useState<string>();
  const [panel, setPanel] = useState<Panel>("chapters");
  const [validationOpen, setValidationOpen] = useState(false);
  const [publishOpen, setPublishOpen] = useState(false);
  const detail = editor.detail;
  if (editor.query.isPending) return <p role="status" className="p-8 text-ink-muted">Đang tải lộ trình…</p>;
  if (!detail) return <ErrorState error={editor.query.error} onRetry={() => void editor.reload()} />;
  const readOnly = detail.version.status !== "DRAFT";
  const disabled = editor.busy || editor.conflict;
  const chapter = detail.chapters.find((row) => row.chapter.id === chapterId) ?? detail.chapters[0];
  const activeEventId = chapter?.events.find((row) => row.node.id === eventId)?.node.id ?? chapter?.events[0]?.node.id;
  const canPublish = !readOnly && !disabled && editor.validation != null
    && editor.validatedRevision === detail.version.revision && !editor.validation.issues.some((issue) => issue.level === "ERROR");
  const select = (nextChapter: string, nextEvent?: string) => { setChapterId(nextChapter); setEventId(nextEvent); setPanel("events"); };
  const change: PathChange = async (...args) => {
    const result = await editor.change(...args);
    if (result && activeEventId) {
      const current = result.chapters.find((row) => row.events.some((event) => event.node.id === activeEventId));
      if (current) { setChapterId(current.chapter.id); setEventId(activeEventId); }
    }
    return result;
  };
  return <div className="flex h-[calc(100dvh-104px)] min-h-[420px] flex-col overflow-hidden rounded-xl border border-border bg-white shadow-sm">
    <header className="shrink-0 space-y-3 border-b border-border bg-surface px-4 py-3">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0"><Link href="/learning-path" className="inline-flex items-center gap-1 text-xs text-brand hover:underline"><ArrowLeft className="size-3" aria-hidden />Các phiên bản</Link><h1 className="mt-1 font-display text-xl font-semibold">{detail.version.title}</h1><div className="mt-1 flex flex-wrap items-center gap-2"><StatusChip status={detail.version.status} /><span className="text-xs text-ink-muted">Phiên bản {detail.version.versionNo} · Lần lưu {detail.version.revision}</span></div></div>
        <div className="flex flex-wrap gap-2">
          <Button asChild variant="secondary" size="sm"><Link href={`/learning-path/${versionId}/preview`}><Eye aria-hidden />Xem trước</Link></Button>
          <Button variant="secondary" size="sm" disabled={editor.busy} onClick={() => void editor.reload()} aria-label="Tải lại lộ trình"><RefreshCw aria-hidden /></Button>
          <Button variant="secondary" size="sm" disabled={disabled} onClick={async () => { const report = await editor.validate(); if (report) setValidationOpen(true); }}><CheckCircle2 aria-hidden />Kiểm tra lộ trình</Button>
          {!readOnly && <Button size="sm" disabled={!canPublish} onClick={() => setPublishOpen(true)}><Save aria-hidden />Xuất bản</Button>}
        </div>
      </div>
      <p className="text-xs text-ink-muted">{readOnly ? "Phiên bản đã xuất bản hoặc lưu trữ: chỉ xem. Tạo bản nháp từ phiên bản hiện hành để chỉnh sửa." : "Thiết kế chương → sự kiện → bài học. Mỗi thay đổi được lưu vào bản nháp khi máy chủ xác nhận."}</p>
      {editor.busy && <p role="status" className="text-xs font-medium text-brand">Đang đồng bộ với máy chủ…</p>}
      {editor.error && <div role="alert" className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-error/30 bg-error/5 px-3 py-2 text-sm text-error"><span>{editor.error}</span>{editor.conflict && <Button variant="secondary" size="sm" disabled={editor.busy} onClick={() => void editor.reload()}>Tải bản mới nhất</Button>}</div>}
      {!readOnly && !editor.validation && <p className="text-xs text-ink-muted">Kiểm tra lại sau mỗi thay đổi trước khi xuất bản.</p>}
    </header>
    <div className="flex shrink-0 border-b border-border xl:hidden" role="tablist" aria-label="Các vùng thiết kế">{TABS.map((tab) => <button key={tab.key} type="button" id={`path-tab-${tab.key}`} role="tab" aria-selected={panel === tab.key} aria-controls={`path-panel-${tab.key}`} onClick={() => setPanel(tab.key)} className={cn("min-h-11 flex-1 border-b-2 px-3 text-sm font-medium", panel === tab.key ? "border-brand text-brand" : "border-transparent text-ink-muted")}>{tab.label}</button>)}</div>
    <div className="grid min-h-0 flex-1 grid-cols-1 xl:grid-cols-[minmax(13rem,0.85fr)_minmax(20rem,1.6fr)_minmax(16rem,1fr)]">
      <div id="path-panel-chapters" aria-labelledby="path-tab-chapters" className={cn("min-h-0 overflow-y-auto overscroll-contain border-r border-border xl:block", panel !== "chapters" && "hidden")}><ChapterPanel detail={detail} selectedId={chapter?.chapter.id} disabled={disabled} readOnly={readOnly} change={change} onSelect={(id) => select(id)} /></div>
      <div id="path-panel-events" aria-labelledby="path-tab-events" className={cn("min-h-0 overflow-y-auto overscroll-contain border-r border-border xl:block", panel !== "events" && "hidden")}><EventPanel detail={detail} chapter={chapter} selectedEventId={activeEventId} disabled={disabled} readOnly={readOnly} change={change} onSelect={setEventId} onSelectChapter={(id) => select(id)} /></div>
      <div id="path-panel-preview" aria-labelledby="path-tab-preview" className={cn("min-h-0 overflow-y-auto overscroll-contain bg-surface xl:block", panel !== "preview" && "hidden")}><PathPreview detail={detail} onSelect={select} /></div>
    </div>
    <Dialog open={validationOpen} onOpenChange={setValidationOpen} title="Kiểm tra điều kiện xuất bản" description="Lỗi chặn xuất bản. Cảnh báo cần xem lại, nhưng không tự thay đổi thứ tự hay nội dung." size="lg"
      footer={<><Button variant="secondary" onClick={() => setValidationOpen(false)}>Đóng</Button>{!readOnly && <Button disabled={!canPublish} onClick={() => { setValidationOpen(false); setPublishOpen(true); }}>Xuất bản lộ trình</Button>}</>}>
      {editor.validation ? <PathValidation report={editor.validation} detail={detail} onSelect={(id, node) => { select(id, node); setValidationOpen(false); }} /> : <p className="text-sm text-ink-muted">Dữ liệu đã thay đổi. Đóng hộp thoại và kiểm tra lại.</p>}
    </Dialog>
    <ConfirmDialog open={publishOpen} onOpenChange={setPublishOpen} title="Xuất bản lộ trình này?" description="Bản nháp trở thành phiên bản hiện hành. Phiên bản trước được lưu trữ và giữ nguyên lịch sử học tập." confirmLabel="Xác nhận xuất bản" onConfirm={() => { if (canPublish) void editor.publish(); }} />
  </div>;
}
