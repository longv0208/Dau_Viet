"use client";

import { useQuery } from "@tanstack/react-query";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminLessonSummary } from "@/lib/dto/lesson";
import { qk } from "@/lib/query-keys";
import { DataTable, type Column } from "@/components/data-table";
import { StatusChip } from "@/components/status-chip";

const COLUMNS: Column<AdminLessonSummary>[] = [
  { key: "title", header: "Tiêu đề", cell: (r) => <span className="font-medium">{r.title}</span> },
  {
    key: "eventId",
    header: "Sự kiện",
    cell: (r) => <span className="text-xs text-ink-muted">{r.eventId}</span>,
  },
  { key: "status", header: "Trạng thái", cell: (r) => <StatusChip status={r.status} /> },
  {
    key: "version",
    header: "Xuất bản",
    cell: (r) =>
      r.currentVersionId ? (
        // AdminLessonSummaryResponse carries currentVersionId, not the
        // version's versionNo — the real number lives on
        // /admin/lessons/{id}/versions/current. Show the honest publication
        // state instead of a fabricated v#.
        <span className="text-xs" title={`ID phiên bản: ${r.currentVersionId}`}>
          Đã xuất bản
        </span>
      ) : (
        <span className="text-xs text-ink-muted">Chưa xuất bản</span>
      ),
  },
];

/** /lessons — real list wired to GET /admin/lessons. */
export function LessonsTable() {
  const query = useQuery({
    queryKey: qk.lessons.list({ size: 20 }),
    queryFn: () =>
      apiFetch<PageResponse<AdminLessonSummary>>(`/admin/lessons${toQuery({ size: 20 })}`),
  });

  return (
    <DataTable
      columns={COLUMNS}
      rows={query.data?.content ?? []}
      rowKey={(r) => r.id}
      loading={query.isPending}
      error={query.error ?? undefined}
      onRetry={() => query.refetch()}
      emptyTitle="Chưa có bài học nào"
      emptyDescription="Các bài học bạn soạn sẽ xuất hiện tại đây."
    />
  );
}
