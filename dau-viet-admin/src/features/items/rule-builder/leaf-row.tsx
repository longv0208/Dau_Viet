"use client";

import { useQuery } from "@tanstack/react-query";
import { ArrowDown, ArrowUp, X } from "lucide-react";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { AdminEventSummary } from "@/lib/dto/event";
import type { Evidence } from "@/lib/dto/evidence";
import { qk } from "@/lib/query-keys";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";

import {
  describeLeaf,
  isLeafComplete,
  type LeafForm,
} from "./rule-ast";

interface PageResponse<T> {
  content: T[];
}

interface LessonSummary {
  id: string;
  title: string;
}

const TYPE_LABELS: Record<LeafForm["type"], string> = {
  LESSON_COMPLETED: "Hoàn thành bài học",
  LESSON_MASTERED: "Thành thạo bài học",
  COLLECTION_COUNT: "Đủ N bằng chứng",
  LESSON_COUNT: "Đủ N bài học",
  EVENT_COMPLETED: "Hoàn thành sự kiện",
  EVENT_MASTERED: "Thành thạo sự kiện",
  EVENT_EVIDENCE_COUNT: "N bằng chứng của sự kiện",
  SPECIFIC_EVIDENCE_SET: "Bộ bằng chứng chỉ định",
  TOTAL_EVENTS_COMPLETED: "Tổng sự kiện hoàn thành",
  TOTAL_EVENTS_MASTERED: "Tổng sự kiện thành thạo",
  LEVEL_AT_LEAST: "Đạt cấp độ",
};

export function usePublishedEvents() {
  return useQuery({
    queryKey: qk.events.list({ status: "PUBLISHED", size: 100 }),
    queryFn: () =>
      apiFetch<PageResponse<AdminEventSummary>>(
        `/admin/events${toQuery({ status: "PUBLISHED", size: 100 })}`,
      ),
  });
}

export function usePublishedLessons() {
  return useQuery({
    queryKey: qk.lessons.list({ status: "PUBLISHED", size: 100 }),
    queryFn: () =>
      apiFetch<PageResponse<LessonSummary>>(
        `/admin/lessons${toQuery({ status: "PUBLISHED", size: 100 })}`,
      ),
  });
}

function EventSelect({
  value,
  onChange,
  events,
}: {
  value: string | undefined;
  onChange: (v: string) => void;
  events: AdminEventSummary[] | undefined;
}) {
  return (
    <Select
      value={value ?? ""}
      onChange={(e) => onChange(e.target.value)}
      aria-label="Sự kiện"
    >
      <option value="">— Chọn sự kiện đã xuất bản —</option>
      {(events ?? []).map((ev) => (
        <option key={ev.id} value={ev.id}>
          {ev.title}
        </option>
      ))}
    </Select>
  );
}

function LessonSelect({
  value,
  onChange,
  lessons,
}: {
  value: string | undefined;
  onChange: (v: string) => void;
  lessons: LessonSummary[] | undefined;
}) {
  return (
    <Select
      value={value ?? ""}
      onChange={(e) => onChange(e.target.value)}
      aria-label="Bài học"
    >
      <option value="">— Chọn bài học đã xuất bản —</option>
      {(lessons ?? []).map((l) => (
        <option key={l.id} value={l.id}>
          {l.title}
        </option>
      ))}
    </Select>
  );
}

function ThresholdInput({
  value,
  onChange,
  label = "Ngưỡng",
}: {
  value: number | undefined;
  onChange: (v: number | undefined) => void;
  label?: string;
}) {
  return (
    <div className="flex flex-col gap-1">
      <Label>{label}</Label>
      <Input
        type="number"
        min={1}
        value={value ?? ""}
        onChange={(e) => {
          const n = e.target.value === "" ? undefined : Number(e.target.value);
          onChange(Number.isFinite(n) ? n : undefined);
        }}
      />
    </div>
  );
}

/** Checkbox multiselect bằng chứng APPROVED của event đã chọn. */
function EvidencePicker({
  eventId,
  selected,
  onChange,
}: {
  eventId: string;
  selected: string[];
  onChange: (ids: string[]) => void;
}) {
  const query = useQuery({
    queryKey: qk.evidences.list({ eventId, status: "APPROVED", size: 100 }),
    queryFn: () =>
      apiFetch<PageResponse<Evidence>>(
        `/admin/evidences${toQuery({ eventId, status: "APPROVED", size: 100 })}`,
      ),
    enabled: Boolean(eventId),
  });

  const toggle = (id: string) => {
    onChange(
      selected.includes(id)
        ? selected.filter((x) => x !== id)
        : [...selected, id],
    );
  };

  if (query.isPending) {
    return <p className="text-xs text-ink-muted">Đang tải bằng chứng…</p>;
  }
  const rows = query.data?.content ?? [];
  if (rows.length === 0) {
    return (
      <p className="text-xs text-ink-muted">
        Sự kiện chưa có bằng chứng APPROVED nào.
      </p>
    );
  }
  return (
    <div className="flex max-h-48 flex-col gap-1 overflow-y-auto rounded-md border border-border p-2">
      {rows.map((ev) => (
        <label
          key={ev.id}
          className="flex cursor-pointer items-center gap-2 rounded px-2 py-1 text-sm hover:bg-surface-alt"
        >
          <input
            type="checkbox"
            checked={selected.includes(ev.id)}
            onChange={() => toggle(ev.id)}
          />
          <span className="min-w-0 truncate">{ev.title}</span>
        </label>
      ))}
    </div>
  );
}

/**
 * Một leaf row trong Rule Tree: badge type + field editors động +
 * reorder + remove + mô tả tự nhiên.
 */
export function LeafRow({
  leaf,
  index,
  count,
  onChange,
  onRemove,
  onMove,
}: {
  leaf: LeafForm;
  index: number;
  count: number;
  onChange: (next: LeafForm) => void;
  onRemove: () => void;
  onMove: (index: number, delta: -1 | 1) => void;
}) {
  const eventsQuery = usePublishedEvents();
  const lessonsQuery = usePublishedLessons();

  const needsEvent =
    leaf.type === "EVENT_COMPLETED" ||
    leaf.type === "EVENT_MASTERED" ||
    leaf.type === "EVENT_EVIDENCE_COUNT" ||
    leaf.type === "SPECIFIC_EVIDENCE_SET";
  const needsLesson =
    leaf.type === "LESSON_COMPLETED" || leaf.type === "LESSON_MASTERED";
  const needsThreshold =
    leaf.type === "LESSON_MASTERED" ||
    leaf.type === "COLLECTION_COUNT" ||
    leaf.type === "LESSON_COUNT" ||
    leaf.type === "EVENT_EVIDENCE_COUNT" ||
    leaf.type === "TOTAL_EVENTS_COMPLETED" ||
    leaf.type === "TOTAL_EVENTS_MASTERED";

  const set = (patch: Partial<LeafForm>) => onChange({ ...leaf, ...patch });

  const lookups = {
    eventTitle: (id: string) =>
      eventsQuery.data?.content.find((e) => e.id === id)?.title,
    lessonTitle: (id: string) =>
      lessonsQuery.data?.content.find((l) => l.id === id)?.title,
  };

  return (
    <li className="rounded-md border border-border bg-white p-3">
      <div className="flex items-center justify-between gap-2">
        <span className="inline-flex items-center rounded-full bg-brand/10 px-2.5 py-0.5 text-xs font-medium text-brand">
          {TYPE_LABELS[leaf.type]}
        </span>
        <div className="flex items-center gap-1">
          <button
            type="button"
            aria-label="Đưa lên"
            disabled={index === 0}
            onClick={() => onMove(index, -1)}
            className="flex size-8 items-center justify-center rounded text-ink-muted hover:bg-surface-alt disabled:opacity-40"
          >
            <ArrowUp className="size-4" aria-hidden />
          </button>
          <button
            type="button"
            aria-label="Đưa xuống"
            disabled={index === count - 1}
            onClick={() => onMove(index, 1)}
            className="flex size-8 items-center justify-center rounded text-ink-muted hover:bg-surface-alt disabled:opacity-40"
          >
            <ArrowDown className="size-4" aria-hidden />
          </button>
          <button
            type="button"
            aria-label="Xoá điều kiện"
            onClick={onRemove}
            className="flex size-8 items-center justify-center rounded text-ink-muted hover:bg-error/10 hover:text-error"
          >
            <X className="size-4" aria-hidden />
          </button>
        </div>
      </div>

      <div className="mt-3 grid grid-cols-1 gap-3 md:grid-cols-2">
        {needsEvent && (
          <div className="flex flex-col gap-1">
            <Label>Sự kiện</Label>
            <EventSelect
              value={leaf.eventId}
              onChange={(eventId) => set({ eventId, evidenceIds: [] })}
              events={eventsQuery.data?.content}
            />
          </div>
        )}
        {needsLesson && (
          <div className="flex flex-col gap-1">
            <Label>Bài học</Label>
            <LessonSelect
              value={leaf.lessonId}
              onChange={(lessonId) => set({ lessonId })}
              lessons={lessonsQuery.data?.content}
            />
          </div>
        )}
        {needsThreshold && (
          <ThresholdInput
            value={leaf.threshold}
            onChange={(threshold) => set({ threshold })}
            label={leaf.type === "LESSON_MASTERED" ? "Ngưỡng điểm (%)" : "Ngưỡng"}
          />
        )}
      </div>

      {leaf.type === "SPECIFIC_EVIDENCE_SET" && leaf.eventId && (
        <div className="mt-3 flex flex-col gap-1">
          <Label>Bằng chứng cần sưu tầm (đã chọn {leaf.evidenceIds?.length ?? 0})</Label>
          <EvidencePicker
            eventId={leaf.eventId}
            selected={leaf.evidenceIds ?? []}
            onChange={(evidenceIds) => set({ evidenceIds })}
          />
        </div>
      )}

      <p className="mt-2 text-xs text-ink-muted">
        {describeLeaf(leaf, lookups)}
      </p>
      {!isLeafComplete(leaf) && (
        <p role="alert" className="mt-1 text-xs text-error">
          Chưa đủ thông tin — điền các trường bắt buộc.
        </p>
      )}
    </li>
  );
}
