"use client";

import Link from "next/link";
import { useState } from "react";
import { useQuery, keepPreviousData } from "@tanstack/react-query";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminEventSummary, EventStatus } from "@/lib/dto/event";
import { qk } from "@/lib/query-keys";
import { DataTable, type Column } from "@/components/data-table";
import { StatusChip } from "@/components/status-chip";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";

const PAGE_SIZE = 20;

/** /events — real list wired to GET /admin/events with search + status + paging. */
export function EventsTable() {
  const [searchInput, setSearchInput] = useState("");
  const [q, setQ] = useState("");
  const [status, setStatus] = useState<EventStatus | "">("");
  const [page, setPage] = useState(0);

  const query = useQuery({
    queryKey: qk.events.list({ page, size: PAGE_SIZE, q: q || undefined, status: status || undefined }),
    queryFn: () =>
      apiFetch<PageResponse<AdminEventSummary>>(
        `/admin/events${toQuery({ page, size: PAGE_SIZE, q: q || undefined, status: status || undefined, sort: "updatedAt,desc" })}`,
      ),
    placeholderData: keepPreviousData,
  });

  const columns: Column<AdminEventSummary>[] = [
    {
      key: "title",
      header: "Tiêu đề",
      cell: (r) => (
        <Link href={`/events/${r.id}`} className="font-medium text-ink hover:underline">
          {r.title}
        </Link>
      ),
    },
    { key: "era", header: "Thời kỳ", cell: (r) => r.era || <span className="text-ink-muted">—</span> },
    { key: "startYear", header: "Năm", cell: (r) => r.startYear ?? "—" },
    { key: "status", header: "Trạng thái", cell: (r) => <StatusChip status={r.status} /> },
    {
      key: "tags",
      header: "Tags",
      cell: (r) => (r.tags.length ? r.tags.join(", ") : <span className="text-ink-muted">—</span>),
    },
    {
      key: "actions",
      header: "",
      cell: (r) => (
        <Link href={`/events/${r.id}`} className="text-sm text-primary hover:underline">
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
            placeholder="Tìm theo tiêu đề..."
            aria-label="Tìm kiếm sự kiện"
          />
          <Button type="submit" variant="secondary">
            Tìm
          </Button>
        </form>
        <Select
          value={status}
          onChange={(e) => {
            setStatus(e.target.value as EventStatus | "");
            setPage(0);
          }}
          aria-label="Lọc theo trạng thái"
          className="w-48"
        >
          <option value="">Tất cả trạng thái</option>
          <option value="DRAFT">Bản nháp</option>
          <option value="PUBLISHED">Đã xuất bản</option>
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
        emptyTitle="Chưa có sự kiện nào"
        emptyDescription="Các sự kiện lịch sử bạn tạo sẽ xuất hiện tại đây."
      />

      {(query.data?.totalElements ?? 0) > 0 && (
        <div className="flex items-center justify-between text-sm text-ink-muted">
          <span>
            Trang {page + 1} / {Math.max(1, totalPages)} ({query.data?.totalElements ?? 0} sự kiện)
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
