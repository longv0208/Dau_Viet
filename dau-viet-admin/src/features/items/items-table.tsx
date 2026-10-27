"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useState } from "react";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminItem } from "@/lib/dto/item";
import { qk } from "@/lib/query-keys";
import { DataTable, type Column } from "@/components/data-table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";

const TYPE_LABELS: Record<AdminItem["itemType"], string> = {
  HISTORICAL_REPLICA: "Mô hình",
  DIGITAL_EDITION: "Phiên bản số",
  COMMEMORATIVE_BADGE: "Huy hiệu",
  DECOR: "Trang trí Đảo Di Sản",
};

const RULE_LABELS: Record<string, string> = {
  LESSON_COMPLETED: "Hoàn thành bài học",
  COLLECTION_COUNT: "Đủ bằng chứng",
  LESSON_COUNT: "Đủ số bài",
  RULE_V2: "Điều kiện nâng cao (AST)",
};

const PAGE_SIZE = 20;

/**
 * /items — danh mục vật phẩm thưởng. GET /admin/items trả PageResponse.
 * Cột "Điều kiện mở khóa" tóm tắt rule đang active.
 */
export function ItemsTable() {
  const [searchInput, setSearchInput] = useState("");
  const [q, setQ] = useState("");
  const [itemType, setItemType] = useState("");
  const [activeFilter, setActiveFilter] = useState("");
  const [page, setPage] = useState(0);

  const active =
    activeFilter === "true" ? true : activeFilter === "false" ? false : undefined;

  const query = useQuery({
    queryKey: qk.items.list({
      page,
      size: PAGE_SIZE,
      active,
      itemType: itemType || undefined,
      q: q || undefined,
    }),
    queryFn: () =>
      apiFetch<PageResponse<AdminItem>>(
        `/admin/items${toQuery({
          page,
          size: PAGE_SIZE,
          active: activeFilter || undefined,
          itemType: itemType || undefined,
          q: q || undefined,
        })}`,
      ),
    placeholderData: keepPreviousData,
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
      key: "placeable",
      header: "Đặt lên đảo",
      cell: (r) => (
        <div className="flex flex-col gap-0.5">
          <span
            className={
              r.placeable
                ? "inline-flex w-fit items-center rounded-full bg-brand/15 px-2 py-0.5 text-xs font-medium text-brand"
                : "text-xs text-ink-muted"
            }
          >
            {r.placeable ? "Có thể đặt" : "Không"}
          </span>
          {r.renderKey && (
            <code className="text-[11px] text-ink-muted">{r.renderKey}</code>
          )}
        </div>
      ),
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

  const totalPages = Math.max(1, query.data?.totalPages ?? 0);
  const totalElements = query.data?.totalElements ?? (query.data?.content.length ?? 0);

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
            placeholder="Tìm theo tên hoặc mã vật phẩm..."
            aria-label="Tìm kiếm vật phẩm"
          />
          <Button type="submit" variant="secondary">
            Tìm
          </Button>
        </form>
        <Select
          value={itemType}
          onChange={(e) => {
            setItemType(e.target.value);
            setPage(0);
          }}
          aria-label="Lọc theo loại vật phẩm"
          className="w-44"
        >
          <option value="">Tất cả loại</option>
          {Object.entries(TYPE_LABELS).map(([k, label]) => (
            <option key={k} value={k}>
              {label}
            </option>
          ))}
        </Select>
        <Select
          value={activeFilter}
          onChange={(e) => {
            setActiveFilter(e.target.value);
            setPage(0);
          }}
          aria-label="Lọc theo trạng thái"
          className="w-40"
        >
          <option value="">Mọi trạng thái</option>
          <option value="true">Đang bật</option>
          <option value="false">Đã ẩn</option>
        </Select>
      </div>

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

      {totalElements > 0 && (
        <div className="flex items-center justify-between text-sm text-ink-muted">
          <span>
            Trang {page + 1} / {totalPages} ({totalElements} vật phẩm)
          </span>
          <div className="flex gap-2">
            <Button
              variant="secondary"
              disabled={page <= 0}
              onClick={() => setPage((p) => p - 1)}
            >
              Trước
            </Button>
            <Button
              variant="secondary"
              disabled={page + 1 >= totalPages}
              onClick={() => setPage((p) => p + 1)}
            >
              Sau
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
