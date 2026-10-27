"use client";

import Link from "next/link";
import { useState } from "react";
import { useQuery, keepPreviousData } from "@tanstack/react-query";

import { apiFetch, toQuery } from "@/lib/api-client";
import { withReturnTo } from "@/lib/return-to";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminEventSummary } from "@/lib/dto/event";
import type { Evidence, EvidenceStatus } from "@/lib/dto/evidence";
import { qk } from "@/lib/query-keys";
import { DataTable, type Column } from "@/components/data-table";
import { StatusChip } from "@/components/status-chip";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";

import { evidenceTypeLabel } from "./evidence-labels";

const PAGE_SIZE = 20;

/**
 * /evidence — real list wired to GET /admin/evidences with q + status +
 * event filters. `lockedEventId` pins the list to one event (workspace
 * context): the event dropdown + "Sự kiện" column hide and row links get
 * `?return=<returnTo>`.
 */
export function EvidenceTable({
  lockedEventId,
  returnTo,
}: {
  lockedEventId?: string;
  returnTo?: string | null;
}) {
  const [searchInput, setSearchInput] = useState("");
  const [q, setQ] = useState("");
  const [status, setStatus] = useState<EvidenceStatus | "">("");
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
    queryKey: qk.evidences.list({
      page,
      size: PAGE_SIZE,
      status: status || undefined,
      eventId: eventId || undefined,
      q: q || undefined,
    }),
    queryFn: () =>
      apiFetch<PageResponse<Evidence>>(
        `/admin/evidences${toQuery({
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

  const columns: Column<Evidence>[] = [
    {
      key: "title",
      header: "Tiêu đề",
      cell: (r) => (
        <Link
          href={withReturnTo(`/evidence/${r.id}`, returnTo ?? null)}
          className="font-medium text-ink hover:underline"
        >
          {r.title}
        </Link>
      ),
    },
    {
      key: "evidenceType",
      header: "Loại",
      cell: (r) => <span className="text-sm">{evidenceTypeLabel(r.evidenceType)}</span>,
    },
    ...(lockedEventId
      ? []
      : [
          {
            key: "eventId",
            header: "Sự kiện",
            cell: (r: Evidence) => (
              <span className="text-xs text-ink-muted">
                {eventsById.get(r.eventId) ?? "—"}
              </span>
            ),
          } satisfies Column<Evidence>,
        ]),
    {
      key: "source",
      header: "Nguồn",
      cell: (r) =>
        r.sourceTitle?.trim() ? (
          <span className="text-sm" title={r.sourceTitle}>
            {r.sourceTitle.length > 48 ? `${r.sourceTitle.slice(0, 48)}…` : r.sourceTitle}
          </span>
        ) : (
          <span className="inline-flex items-center gap-1 rounded-full bg-warning/25 px-2 py-0.5 text-xs font-medium text-ink">
            Chưa đủ nguồn
          </span>
        ),
    },
    { key: "status", header: "Trạng thái", cell: (r) => <StatusChip status={r.status} /> },
    {
      key: "actions",
      header: "",
      cell: (r) => (
        <Link
          href={withReturnTo(`/evidence/${r.id}`, returnTo ?? null)}
          className="text-sm text-primary hover:underline"
        >
          Sửa
        </Link>
      ),
    },
  ];

  const totalPages = query.data?.totalPages ?? 0;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3">
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
            placeholder="Tìm theo tiêu đề hoặc nguồn..."
            aria-label="Tìm kiếm bằng chứng"
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
            setStatus(e.target.value as EvidenceStatus | "");
            setPage(0);
          }}
          aria-label="Lọc theo trạng thái"
          className="w-48"
        >
          <option value="">Tất cả trạng thái</option>
          <option value="DRAFT">Bản nháp</option>
          <option value="APPROVED">Đã phê duyệt</option>
          <option value="ARCHIVED">Đã lưu trữ</option>
        </Select>
      </div>

      <DataTable
        columns={columns}
        rows={query.data?.content ?? []}
        rowKey={(r) => r.id}
        loading={query.isPending}
        error={query.error ?? undefined}
        onRetry={() => query.refetch()}
        emptyTitle="Chưa có bằng chứng nào"
        emptyDescription="Các bằng chứng lịch sử có nguồn rõ ràng sẽ xuất hiện tại đây."
      />

      {(query.data?.totalElements ?? 0) > 0 && (
        <div className="flex items-center justify-between text-sm text-ink-muted">
          <span>
            Trang {page + 1} / {Math.max(1, totalPages)} ({query.data?.totalElements ?? 0} bằng chứng)
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
