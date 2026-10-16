"use client";

import { useQuery } from "@tanstack/react-query";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminEventSummary } from "@/lib/dto/event";
import { qk } from "@/lib/query-keys";
import { DataTable, type Column } from "@/components/data-table";
import { StatusChip } from "@/components/status-chip";

const COLUMNS: Column<AdminEventSummary>[] = [
  { key: "title", header: "Tiêu đề", cell: (r) => <span className="font-medium">{r.title}</span> },
  { key: "era", header: "Thời kỳ", cell: (r) => r.era },
  { key: "startYear", header: "Năm", cell: (r) => r.startYear ?? "—" },
  { key: "status", header: "Trạng thái", cell: (r) => <StatusChip status={r.status} /> },
  {
    key: "tags",
    header: "Tags",
    cell: (r) => (r.tags.length ? r.tags.join(", ") : <span className="text-ink-muted">—</span>),
  },
];

/** /events — real list wired to GET /admin/events. */
export function EventsTable() {
  const query = useQuery({
    queryKey: qk.events.list({ size: 20 }),
    queryFn: () =>
      apiFetch<PageResponse<AdminEventSummary>>(`/admin/events${toQuery({ size: 20 })}`),
  });

  return (
    <DataTable
      columns={COLUMNS}
      rows={query.data?.content ?? []}
      rowKey={(r) => r.id}
      loading={query.isPending}
      error={query.error ?? undefined}
      onRetry={() => query.refetch()}
      emptyTitle="Chưa có sự kiện nào"
      emptyDescription="Các sự kiện lịch sử bạn tạo sẽ xuất hiện tại đây."
    />
  );
}
