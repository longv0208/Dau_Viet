"use client";

import Link from "next/link";
import { useState } from "react";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminEventSummary } from "@/lib/dto/event";
import type { PathDetail } from "@/lib/dto/learning-path";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { StatusChip } from "@/components/status-chip";
import { ErrorState } from "@/components/error-state";
import { historicalYear, type PathChange } from "./builder-types";

export function EventCatalog({ detail, chapterId, disabled, change, onAdded }: {
  detail: PathDetail; chapterId: string; disabled: boolean; change: PathChange;
  onAdded: (eventNodeId: string) => void;
}) {
  const [input, setInput] = useState("");
  const [q, setQ] = useState("");
  const [page, setPage] = useState(0);
  const query = useQuery({ queryKey: ["learning-path", "event-catalog", q, page],
    queryFn: () => apiFetch<PageResponse<AdminEventSummary>>(`/admin/events${toQuery({ q, page, size: 12, sort: "title,asc" })}`),
    placeholderData: keepPreviousData });
  const attached = new Set(detail.chapters.flatMap((row) => row.events.map((event) => event.node.eventId)));
  return <section className="space-y-3 rounded-lg border border-border bg-surface p-3" aria-label="Kho sự kiện">
    <div className="flex flex-wrap items-center justify-between gap-2"><h3 className="font-semibold">Kho sự kiện có sẵn</h3><Link href="/events" className="text-xs text-brand underline">Quản lý nội dung sự kiện</Link></div>
    <form className="flex gap-2" onSubmit={(event) => { event.preventDefault(); setQ(input.trim()); setPage(0); }}>
      <Input aria-label="Tìm sự kiện theo tên hoặc năm" placeholder="Tên sự kiện hoặc năm…" value={input} onChange={(event) => setInput(event.target.value)} />
      <Button type="submit" variant="secondary" disabled={query.isFetching}>Tìm</Button>
    </form>
    <p className="text-xs text-ink-muted">Sự kiện được thêm ở chế độ tham khảo. Chọn sự kiện để gắn bài và cấu hình bắt buộc.</p>
    {query.isPending && <p role="status" className="text-sm text-ink-muted">Đang tải kho sự kiện…</p>}
    {query.isError && <ErrorState error={query.error} onRetry={() => void query.refetch()} />}
    {query.data && <>
      <ul className="divide-y divide-border">
        {query.data.content.map((event) => <li key={event.id} className="flex items-center gap-3 py-3">
          <div className="min-w-0 flex-1"><p className="text-sm font-medium">{event.title}</p><div className="mt-1 flex flex-wrap items-center gap-2"><span className="text-xs text-ink-muted">{historicalYear(event.startYear)}</span><StatusChip status={event.status} /></div></div>
          <Button variant="secondary" size="sm" disabled={disabled || query.isPlaceholderData || attached.has(event.id) || event.status === "ARCHIVED"}
            onClick={async () => { const result = await change(`/chapters/${chapterId}/events`, "POST", { eventId: event.id, participationType: "EXPLORATION_ONLY" });
              const added = result?.chapters.flatMap((row) => row.events).find((row) => row.node.eventId === event.id);
              if (added) onAdded(added.node.id);
            }}>{attached.has(event.id) ? "Đã gắn" : event.status === "ARCHIVED" ? "Đã lưu trữ" : "Thêm"}</Button>
        </li>)}
      </ul>
      {query.data.content.length === 0 && <p className="py-3 text-sm text-ink-muted">Không có sự kiện phù hợp.</p>}
      <div className="flex items-center justify-between gap-2"><Button variant="ghost" size="sm" disabled={page === 0 || query.isFetching} onClick={() => setPage((value) => value - 1)}>Trước</Button><span className="text-xs text-ink-muted">Trang {page + 1} / {Math.max(1, query.data.totalPages)}</span><Button variant="ghost" size="sm" disabled={page + 1 >= query.data.totalPages || query.isFetching} onClick={() => setPage((value) => value + 1)}>Sau</Button></div>
    </>}
  </section>;
}
