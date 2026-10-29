"use client";

import Link from "next/link";
import { useState } from "react";
import { useQuery, keepPreviousData } from "@tanstack/react-query";

import { apiFetch, toQuery } from "@/lib/api-client";
import { withReturnTo } from "@/lib/return-to";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminEventSummary } from "@/lib/dto/event";
import type { AdminLessonSummary, LessonStatus } from "@/lib/dto/lesson";
import { qk } from "@/lib/query-keys";
import { PaperCard } from "@/components/atoms/paper-card";
import { StampSeal } from "@/components/atoms/stamp-seal";
import { DataTable, type Column } from "@/components/data-table";
import { StatusChip } from "@/components/status-chip";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";

const PAGE_SIZE = 20;

/**
 * /lessons — real list wired to GET /admin/lessons with event/status/q
 * filters. `lockedEventId` pins the list to one event (workspace context):
 * the event dropdown + "Sự kiện" column hide, and every row link gets
 * `?return=<returnTo>` so the admin lands back on the right tab after
 * editing.
 */
export function LessonsTable({
  lockedEventId,
  returnTo,
}: {
  lockedEventId?: string;
  returnTo?: string | null;
}) {
  const [searchInput, setSearchInput] = useState("");
  const [q, setQ] = useState("");
  const [status, setStatus] = useState<LessonStatus | "">("");
  const [eventIdFilter, setEventIdFilter] = useState("");
  const eventId = lockedEventId ?? eventIdFilter;
  const [page, setPage] = useState(0);

  const eventsQuery = useQuery({
    queryKey: qk.events.list({ size: 100 }),
    queryFn: () =>
      apiFetch<PageResponse<AdminEventSummary>>(`/admin/events${toQuery({ size: 100 })}`),
  });
  const eventsById = new Map((eventsQuery.data?.content ?? []).map((e) => [e.id, e.title]));

  const query = useQuery({
    queryKey: qk.lessons.list({
      page,
      size: PAGE_SIZE,
      status: status || undefined,
      eventId: eventId || undefined,
      q: q || undefined,
    }),
    queryFn: () =>
      apiFetch<PageResponse<AdminLessonSummary>>(
        `/admin/lessons${toQuery({
          page,
          size: PAGE_SIZE,
          sort: "updatedAt,desc",
          status: status || undefined,
          eventId: eventId || undefined,
          q: q || undefined,
        })}`,
      ),
    placeholderData: keepPreviousData,
  });

  const columns: Column<AdminLessonSummary>[] = [
    {
      key: "title",
      header: "Tiêu đề",
      cell: (r) => (
        <Link
          href={withReturnTo(`/lessons/${r.id}`, returnTo ?? null)}
          className="font-medium text-ink hover:underline"
        >
          {r.title}
        </Link>
      ),
    },
    ...(lockedEventId
      ? []
      : [
          {
            key: "eventId",
            header: "Sự kiện",
            cell: (r: AdminLessonSummary) => (
              <span className="text-xs text-ink-muted">
                {eventsById.get(r.eventId) ?? "—"}
              </span>
            ),
          } satisfies Column<AdminLessonSummary>,
        ]),
    { key: "status", header: "Trạng thái", cell: (r) => <StatusChip status={r.status} /> },
    {
      key: "version",
      header: "Xuất bản",
      cell: (r) =>
        r.currentVersionId ? (
          <span className="inline-flex items-center gap-1.5 text-xs">
            <span>Đã xuất bản</span>
            <StampSeal variant="success" label="ẤN" className="scale-75" />
          </span>
        ) : (
          <span className="text-xs text-ink-muted">Chưa xuất bản</span>
        ),
    },
    {
      key: "actions",
      header: "",
      cell: (r) => (
        <div className="flex items-center gap-3">
          <Link
            href={withReturnTo(`/lessons/${r.id}`, returnTo ?? null)}
            className="text-sm font-medium text-brand hover:underline"
          >
            Mở
          </Link>
          <Link
            href={withReturnTo(`/lessons/${r.id}/preview`, returnTo ?? null)}
            className="text-sm text-ink-muted hover:underline"
          >
            Xem trước
          </Link>
          <Link
            href={withReturnTo(`/lessons/${r.id}/publish`, returnTo ?? null)}
            className="text-sm text-ink-muted hover:underline"
          >
            Xuất bản
          </Link>
          <Link
            href={withReturnTo(`/versions?lesson=${r.id}`, returnTo ?? null)}
            className="text-sm text-ink-muted hover:underline"
          >
            Phiên bản
          </Link>
        </div>
      ),
    },
  ];

  const totalPages = query.data?.totalPages ?? 0;

  return (
    <div className="flex flex-col gap-4">
      <PaperCard className="flex flex-wrap items-center gap-3 p-4">
        <form
          onSubmit={(e) => {
            e.preventDefault();
            setQ(searchInput.trim());
            setPage(0);
          }}
          className="flex min-w-64 flex-1 items-center gap-2"
        >
          <Input
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder="Tìm theo tiêu đề hoặc câu hỏi..."
            aria-label="Tìm kiếm bài học"
          />
          <Button type="submit" variant="secondary">
            Tìm
          </Button>
        </form>
        {!lockedEventId && (
          <Select
            value={eventIdFilter}
            onChange={(e) => {
              setEventIdFilter(e.target.value);
              setPage(0);
            }}
            aria-label="Lọc theo sự kiện"
            className="w-56"
          >
            <option value="">Tất cả sự kiện</option>
            {(eventsQuery.data?.content ?? []).map((ev) => (
              <option key={ev.id} value={ev.id}>
                {ev.title}
              </option>
            ))}
          </Select>
        )}
        <Select
          value={status}
          onChange={(e) => {
            setStatus(e.target.value as LessonStatus | "");
            setPage(0);
          }}
          aria-label="Lọc theo trạng thái"
          className="w-44"
        >
          <option value="">Tất cả trạng thái</option>
          <option value="DRAFT">Bản nháp</option>
          <option value="PUBLISHED">Đã xuất bản</option>
          <option value="ARCHIVED">Đã lưu trữ</option>
        </Select>
      </PaperCard>

      <DataTable
        columns={columns}
        rows={query.data?.content ?? []}
        rowKey={(r) => r.id}
        loading={query.isPending}
        error={query.error ?? undefined}
        onRetry={() => query.refetch()}
        emptyTitle="Chưa có bài học nào"
        emptyDescription="Các bài học bạn soạn sẽ xuất hiện tại đây."
      />

      {(query.data?.totalElements ?? 0) > 0 && (
        <div className="flex items-center justify-between text-sm text-ink-muted">
          <span>
            Trang {page + 1} / {Math.max(1, totalPages)} ({query.data?.totalElements ?? 0} bài học)
          </span>
          <div className="flex gap-2">
            <Button variant="secondary" disabled={page === 0} onClick={() => setPage(page - 1)}>
              Trước
            </Button>
            <Button
              variant="secondary"
              disabled={page + 1 >= Math.max(1, totalPages)}
              onClick={() => setPage(page + 1)}
            >
              Sau
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
