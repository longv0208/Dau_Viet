"use client";

import { useEffect, useState } from "react";
import { BookOpen, Compass, Info, Landmark, Trash2 } from "lucide-react";
import type { PathChapter, PathDetail, PathEvent } from "@/lib/dto/learning-path";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { StatusChip } from "@/components/status-chip";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { cn } from "@/lib/utils";
import { SortableList } from "./sortable-list";
import { EventCatalog } from "./event-catalog";
import { LessonPanel } from "./lesson-panel";
import {
  canAttachEventsToChapter,
  CONTENT_LABELS,
  historicalYear,
  NODE_TYPE_META,
  type PathChange,
  resolveNodeType,
} from "./builder-types";

export function EventPanel({
  detail,
  chapter,
  selectedEventId,
  disabled,
  readOnly,
  change,
  onSelect,
  onSelectChapter,
}: {
  detail: PathDetail;
  chapter?: PathChapter;
  selectedEventId?: string;
  disabled: boolean;
  readOnly: boolean;
  change: PathChange;
  onSelect: (id: string) => void;
  onSelectChapter?: (chapterId: string) => void;
}) {
  const [removing, setRemoving] = useState<PathEvent | null>(null);
  const selected = chapter?.events.find((event) => event.node.id === selectedEventId);

  useEffect(() => {
    if (selectedEventId) {
      document.getElementById(`path-event-${selectedEventId}`)?.scrollIntoView({ block: "nearest" });
    }
  }, [selectedEventId]);

  if (!chapter) {
    return (
      <div className="p-8 text-center text-sm text-ink-muted">
        Thêm hoặc chọn một Thời kỳ (PERIOD) hoặc Giai đoạn (PHASE) ở cột trái để thiết kế hành trình.
      </div>
    );
  }

  const nodeType = resolveNodeType(chapter);
  const meta = NODE_TYPE_META[nodeType];
  const attachable = canAttachEventsToChapter(chapter);
  const childPeriods = detail.chapters
    .filter((c) => c.chapter.parentId === chapter.chapter.id)
    .sort((a, b) => a.chapter.sortOrder - b.chapter.sortOrder);
  const attachableChapters = detail.chapters.filter((c) => canAttachEventsToChapter(c));

  if (!attachable) {
    return (
      <section className="space-y-5 p-4" aria-label="Thông tin Đại thời kỳ">
        <div>
          <span
            className={cn(
              "inline-flex items-center gap-1 rounded px-2 py-0.5 text-xs font-semibold uppercase tracking-wider",
              meta.badgeClass,
            )}
          >
            <Landmark className="size-3.5" aria-hidden />
            {meta.label} · Thứ tự {chapter.chapter.sortOrder}
          </span>
          <h2 className="mt-1.5 font-display text-xl font-semibold">{chapter.chapter.title}</h2>
          <p className="mt-1 text-sm text-ink-muted">
            {chapter.chapter.periodLabel} ({historicalYear(chapter.chapter.startYear)} –{" "}
            {historicalYear(chapter.chapter.endYear)})
          </p>
          {chapter.chapter.description && (
            <p className="mt-2 text-sm text-ink">{chapter.chapter.description}</p>
          )}
        </div>

        <div className="rounded-lg border border-warning/50 bg-surface-alt p-4 text-sm text-ink">
          <div className="flex items-start gap-2.5">
            <Info className="mt-0.5 size-4 shrink-0 text-brand" aria-hidden />
            <div className="space-y-1">
              <p className="font-semibold">
                Đại thời kỳ (ERA) không gắn sự kiện trực tiếp
              </p>
              <p className="text-xs text-ink-muted">
                Theo kiến trúc cây lộ trình 2 cấp của Dấu Việt, các Sự kiện lịch sử và Bài học được gắn vào{" "}
                <strong>Thời kỳ (PERIOD)</strong> hoặc <strong>Giai đoạn con (PHASE)</strong> trực thuộc Đại thời kỳ này.
              </p>
            </div>
          </div>
        </div>

        <div className="space-y-2.5">
          <h3 className="text-sm font-semibold text-ink">
            Các Thời kỳ (PERIOD) thuộc {chapter.chapter.title} ({childPeriods.length})
          </h3>
          {childPeriods.length === 0 ? (
            <p className="rounded-lg border border-dashed border-border p-4 text-sm text-ink-muted">
              Đại thời kỳ này chưa có Thời kỳ (PERIOD) con. Hãy bấm nút <strong>+ Thời kỳ</strong> ngay trên thẻ Đại thời kỳ ở cột bên trái để thêm.
            </p>
          ) : (
            <ul className="grid gap-2 sm:grid-cols-2">
              {childPeriods.map((period) => (
                <li key={period.chapter.id}>
                  <button
                    type="button"
                    onClick={() => onSelectChapter?.(period.chapter.id)}
                    className="flex w-full cursor-pointer flex-col rounded-lg border border-border bg-white p-3 text-left shadow-sm transition-colors duration-150 hover:border-brand/50 hover:bg-surface-alt/50"
                  >
                    <span className="inline-flex items-center gap-1 text-xs font-semibold text-brand">
                      <Compass className="size-3.5" aria-hidden />
                      Thời kỳ {period.chapter.sortOrder}
                    </span>
                    <span className="mt-1 font-medium text-ink">{period.chapter.title}</span>
                    <span className="mt-0.5 text-xs text-ink-muted">
                      {period.chapter.periodLabel} · {period.events.length} sự kiện
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>
    );
  }

  return (
    <section className="space-y-5 p-4" aria-label="Sự kiện và bài học">
      <div>
        <span
          className={cn(
            "inline-flex items-center gap-1 rounded px-2 py-0.5 text-xs font-semibold uppercase tracking-wider",
            meta.badgeClass,
          )}
        >
          {meta.shortLabel} {chapter.chapter.sortOrder}
        </span>
        <h2 className="mt-1 font-display text-xl font-semibold">{chapter.chapter.title}</h2>
        <p className="mt-1 text-sm text-ink-muted">
          {chapter.chapter.periodLabel} · {chapter.events.length} sự kiện
        </p>
      </div>

      <SortableList
        items={chapter.events}
        getId={(event) => event.node.id}
        scope={`events:${chapter.chapter.id}`}
        disabled={disabled || readOnly}
        onReorder={(eventNodeIds) =>
          change(`/chapters/${chapter.chapter.id}/events/reorder`, "PUT", { eventNodeIds })
        }
      >
        {(event) => (
          <article
            id={`path-event-${event.node.id}`}
            className={cn(
              "rounded-md p-2 transition-colors duration-150",
              selectedEventId === event.node.id && "bg-surface-alt ring-1 ring-brand/30",
            )}
          >
            <button
              type="button"
              className="w-full cursor-pointer py-2 text-left"
              aria-pressed={selectedEventId === event.node.id}
              onClick={() => onSelect(event.node.id)}
            >
              <span className="text-xs font-semibold text-brand">
                Sự kiện {event.node.sortOrder} · {historicalYear(event.startYear)}
              </span>
              <span className="mt-1 block font-semibold">
                {event.title ?? "Sự kiện không còn tồn tại"}
              </span>
              <span className="mt-2 flex flex-wrap items-center gap-2">
                <StatusChip status={event.eventStatus ?? "DRAFT"} />
                <span className="text-xs text-ink-muted">{event.lessons.length} bài học</span>
                <BookOpen className="size-3.5 text-ink-muted" aria-hidden />
              </span>
            </button>
            <p
              className={cn(
                "mt-1 text-xs",
                event.contentStatus === "PLAYABLE" ? "text-ink-muted" : "text-error",
              )}
            >
              {CONTENT_LABELS[event.contentStatus] ?? event.contentStatus}
            </p>
            <p className="mt-1 text-xs text-ink-muted">
              {event.publishedPolicyId
                ? `Policy đã xuất bản · v${event.publishedPolicyVersion}`
                : "Chưa có policy đã xuất bản"}
            </p>
            {event.alias && (
              <p className="mt-2 rounded border border-warning bg-warning/10 p-2 text-xs">
                Đây là tên thay thế (alias) của một sự kiện canonical. Không thêm đại diện khác của cùng sự kiện vào lộ trình.
              </p>
            )}
            {!readOnly ? (
              <div className="mt-3 space-y-2">
                <label className="block text-xs font-medium">
                  Vai trò trong lộ trình
                  <Select
                    disabled={disabled}
                    className="mt-1"
                    value={event.node.participationType}
                    onChange={(value) =>
                      void change(`/events/${event.node.id}`, "PATCH", {
                        participationType: value.target.value,
                      })
                    }
                  >
                    <option value="EXPLORATION_ONLY">Tham khảo — không chặn tiến độ</option>
                    <option value="REQUIRED">Bắt buộc trong lộ trình</option>
                  </Select>
                </label>
                {event.node.participationType === "REQUIRED" &&
                  event.contentStatus !== "PLAYABLE" && (
                    <p className="text-xs text-error">
                      Sự kiện bắt buộc chưa sẵn sàng; cần hoàn thiện bài học và policy trước khi xuất bản.
                    </p>
                  )}
                <div className="flex items-end gap-2">
                  <label className="min-w-0 flex-1 text-xs font-medium">
                    Chuyển sang Thời kỳ / Giai đoạn
                    <Select
                      disabled={disabled}
                      className="mt-1"
                      value={chapter.chapter.id}
                      onChange={(value) =>
                        void change(`/events/${event.node.id}`, "PATCH", {
                          chapterId: value.target.value,
                        })
                      }
                    >
                      {attachableChapters.map((row) => (
                        <option key={row.chapter.id} value={row.chapter.id}>
                          [{resolveNodeType(row)}] {row.chapter.title}
                        </option>
                      ))}
                    </Select>
                  </label>
                  <Button
                    variant="ghost"
                    size="icon"
                    disabled={disabled}
                    aria-label={`Gỡ sự kiện ${event.title}`}
                    onClick={() => setRemoving(event)}
                  >
                    <Trash2 aria-hidden />
                  </Button>
                </div>
              </div>
            ) : (
              <p className="mt-2 text-xs font-semibold">
                {event.node.participationType === "REQUIRED"
                  ? "Bắt buộc trong lộ trình"
                  : "Tham khảo"}
              </p>
            )}
          </article>
        )}
      </SortableList>

      {chapter.events.length === 0 && (
        <p className="rounded-lg border border-dashed border-border p-4 text-sm text-ink-muted">
          Thời kỳ / Giai đoạn này chưa có sự kiện nào. Chọn sự kiện từ danh mục bên dưới để thêm vào lộ trình.
        </p>
      )}
      {selected && (
        <LessonPanel
          key={selected.node.id}
          event={selected}
          disabled={disabled}
          readOnly={readOnly}
          change={change}
        />
      )}
      {!readOnly && (
        <EventCatalog
          key={chapter.chapter.id}
          detail={detail}
          chapterId={chapter.chapter.id}
          disabled={disabled}
          change={change}
          onAdded={onSelect}
        />
      )}
      <ConfirmDialog
        open={removing != null}
        onOpenChange={(open) => {
          if (!open) setRemoving(null);
        }}
        title="Gỡ sự kiện khỏi lộ trình?"
        description="Các liên kết bài học của sự kiện trong bản nháp cũng được gỡ. Nội dung gốc không bị xóa."
        destructive
        confirmLabel="Gỡ sự kiện"
        onConfirm={() => {
          if (removing && !disabled) void change(`/events/${removing.node.id}`, "DELETE");
        }}
      />
    </section>
  );
}
