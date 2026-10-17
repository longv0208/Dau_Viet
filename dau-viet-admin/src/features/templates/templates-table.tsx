"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";

import { apiFetch } from "@/lib/api-client";
import type { LessonTemplate } from "@/lib/dto/lesson";
import { qk } from "@/lib/query-keys";
import { DataTable, type Column } from "@/components/data-table";

const COLUMNS: Column<LessonTemplate>[] = [
  {
    key: "name",
    header: "Tên mẫu",
    cell: (r) => (
      <Link href={`/templates/${r.id}`} className="font-medium text-primary hover:underline">
        {r.name}
      </Link>
    ),
  },
  { key: "code", header: "Mã", cell: (r) => <code className="text-xs">{r.code}</code> },
  {
    key: "description",
    header: "Mô tả",
    cell: (r) => <span className="text-ink-muted">{r.description}</span>,
  },
];

/**
 * /templates — read-only catalogue. GET /admin/lesson-templates returns a
 * plain array (not PageResponse).
 */
export function TemplatesTable() {
  const query = useQuery({
    queryKey: qk.templates.list(),
    queryFn: () => apiFetch<LessonTemplate[]>("/admin/lesson-templates"),
  });

  return (
    <DataTable
      columns={COLUMNS}
      rows={query.data ?? []}
      rowKey={(r) => r.id}
      loading={query.isPending}
      error={query.error ?? undefined}
      onRetry={() => query.refetch()}
      emptyTitle="Chưa có mẫu bài học nào"
      emptyDescription="Các mẫu hoạt động chuẩn sẽ xuất hiện tại đây."
    />
  );
}
