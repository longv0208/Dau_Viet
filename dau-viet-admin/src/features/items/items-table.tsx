"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { AdminItem } from "@/lib/dto/item";
import { qk } from "@/lib/query-keys";
import { DataTable, type Column } from "@/components/data-table";

const TYPE_LABELS: Record<AdminItem["itemType"], string> = {
  HISTORICAL_REPLICA: "Mô hình",
  DIGITAL_EDITION: "Phiên bản số",
  COMMEMORATIVE_BADGE: "Huy hiệu",
};

const RULE_LABELS: Record<string, string> = {
  LESSON_COMPLETED: "Hoàn thành bài học",
  COLLECTION_COUNT: "Đủ bằng chứng",
  LESSON_COUNT: "Đủ số bài",
};

interface PageResponse<T> {
  content: T[];
  totalElements: number;
}

/**
 * /items — danh mục vật phẩm thưởng. GET /admin/items trả PageResponse.
 * Cột "Điều kiện mở khóa" tóm tắt rule đang active.
 */
export function ItemsTable() {
  const query = useQuery({
    queryKey: qk.items.list(),
    queryFn: () =>
      apiFetch<PageResponse<AdminItem>>(
        `/admin/items${toQuery({ size: 100 })}`,
      ),
  });

  const columns: Column<AdminItem>[] = [
    {
      key: "name",
      header: "Vật phẩm",
      cell: (r) => (
        <Link
          href={`/items/${r.id}`}
          className="font-medium text-primary hover:underline"
        >
          {r.name}
        </Link>
      ),
    },
    {
      key: "code",
      header: "Mã",
      cell: (r) => <code className="text-xs">{r.code}</code>,
    },
    {
      key: "itemType",
      header: "Loại",
      cell: (r) => TYPE_LABELS[r.itemType] ?? r.itemType,
    },
    {
      key: "rule",
      header: "Điều kiện mở khóa",
      cell: (r) =>
        r.rule ? (
          <span className="text-ink-muted">
            {RULE_LABELS[r.rule.ruleType] ?? r.rule.ruleType}
            {r.rule.threshold != null ? ` (≥ ${r.rule.threshold})` : ""}
          </span>
        ) : (
          <span className="text-ink-muted">Chưa cấu hình</span>
        ),
    },
    {
      key: "active",
      header: "Trạng thái",
      cell: (r) => (
        <span
          className={
            r.active
              ? "inline-flex items-center rounded-full bg-success/20 px-2.5 py-0.5 text-xs font-medium text-ink"
              : "inline-flex items-center rounded-full bg-surface-alt px-2.5 py-0.5 text-xs font-medium text-ink-muted"
          }
        >
          {r.active ? "Đang bật" : "Đã ẩn"}
        </span>
      ),
    },
  ];

  return (
    <DataTable
      columns={columns}
      rows={query.data?.content ?? []}
      rowKey={(r) => r.id}
      loading={query.isPending}
      error={query.error ?? undefined}
      onRetry={() => query.refetch()}
      emptyTitle="Chưa có vật phẩm nào"
      emptyDescription="Catalog vật phẩm phần thưởng sẽ xuất hiện tại đây."
    />
  );
}
