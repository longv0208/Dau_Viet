"use client";

import { useState } from "react";
import { Pencil, Plus, Trash2 } from "lucide-react";
import type { PathChapter, PathDetail } from "@/lib/dto/learning-path";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { cn } from "@/lib/utils";
import { ChapterForm } from "./chapter-form";
import { SortableList } from "./sortable-list";
import { historicalYear, type PathChange } from "./builder-types";

export function ChapterPanel({ detail, selectedId, disabled, readOnly, onSelect, change }: {
  detail: PathDetail; selectedId?: string; disabled: boolean; readOnly: boolean;
  onSelect: (id: string) => void; change: PathChange;
}) {
  const [editing, setEditing] = useState<PathChapter | "new" | null>(null);
  const [deleting, setDeleting] = useState<PathChapter | null>(null);
  return <section aria-label="Danh sách chương" className="space-y-3 p-4">
    <div className="flex items-center justify-between gap-2"><h2 className="font-display text-lg font-semibold">Chương lịch sử</h2>
      {!readOnly && <Button variant="secondary" size="icon" aria-label="Thêm chương" disabled={disabled} onClick={() => setEditing("new")}><Plus aria-hidden /></Button>}
    </div>
    <p className="text-xs text-ink-muted">Chọn chương để sắp xếp sự kiện. Kéo tay nắm hoặc dùng nút lên/xuống.</p>
    <SortableList items={detail.chapters} getId={(row) => row.chapter.id} scope={`chapters:${detail.version.id}`} disabled={readOnly || disabled}
      onReorder={(chapterIds) => change("/chapters/reorder", "PUT", { chapterIds })}>
      {(row) => <div>
        <button type="button" onClick={() => onSelect(row.chapter.id)} aria-pressed={selectedId === row.chapter.id}
          className={cn("w-full rounded-md px-2 py-3 text-left hover:bg-surface-alt", selectedId === row.chapter.id && "bg-surface-alt ring-1 ring-brand/30")}>
          <span className="text-xs font-semibold uppercase tracking-wider text-brand">Chương {row.chapter.sortOrder}</span>
          <span className="mt-1 block font-medium">{row.chapter.title}</span>
          <span className="mt-1 block text-xs text-ink-muted">{historicalYear(row.chapter.startYear)} – {historicalYear(row.chapter.endYear)}</span>
          <span className="mt-1 block text-xs text-ink-muted">{row.events.length} sự kiện</span>
        </button>
        {!readOnly && <div className="mt-1 flex flex-wrap gap-1">
          <Button variant="ghost" size="icon" disabled={disabled} aria-label={`Sửa chương ${row.chapter.title}`} onClick={() => setEditing(row)}><Pencil aria-hidden /></Button>
          <Button variant="ghost" size="icon" disabled={disabled || row.events.length > 0} title={row.events.length ? "Di chuyển hoặc gỡ hết sự kiện trước khi xóa chương" : "Xóa chương rỗng"} aria-label={`Xóa chương ${row.chapter.title}`} onClick={() => setDeleting(row)}><Trash2 aria-hidden /></Button>
          {row.events.length > 0 && <span className="self-center text-xs text-ink-muted">Chỉ xóa chương rỗng</span>}
        </div>}
      </div>}
    </SortableList>
    {detail.chapters.length === 0 && <p className="rounded-lg border border-dashed border-border p-5 text-sm text-ink-muted">Chưa có chương. Thêm chương đầu tiên để bắt đầu thiết kế.</p>}
    {editing && <ChapterForm chapter={editing === "new" ? undefined : editing} busy={disabled} onClose={() => setEditing(null)} onSave={async (values) => {
      const result = await change(editing === "new" ? "/chapters" : `/chapters/${editing.chapter.id}`, editing === "new" ? "POST" : "PATCH", values);
      if (result && editing === "new") {
        const added = result.chapters.find((row) => !detail.chapters.some((old) => old.chapter.id === row.chapter.id));
        if (added) onSelect(added.chapter.id);
      }
      return result != null;
    }} />}
    <ConfirmDialog open={deleting != null} onOpenChange={(open) => { if (!open) setDeleting(null); }} title="Xóa chương rỗng?"
      description={deleting?.chapter.title} destructive confirmLabel="Xóa chương" onConfirm={() => { if (deleting && !disabled) void change(`/chapters/${deleting.chapter.id}`, "DELETE"); }} />
  </section>;
}
