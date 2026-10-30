"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useState } from "react";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminItem } from "@/lib/dto/item";
import { qk } from "@/lib/query-keys";
import { ClueTag } from "@/components/atoms/clue-tag";
import { PaperCard } from "@/components/atoms/paper-card";
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
      headerTooltip: "Tên hiển thị của vật phẩm thưởng trong Kho Sưu tập và Đảo Di Sản của học viên.",
      cell: (r) => (
        <div className="flex flex-col gap-0.5">
          <Link
            href={`/items/${r.id}`}
            className="font-medium text-brand hover:underline"
          >
            {r.name}
          </Link>
          {r.description && (
            <span className="max-w-xs truncate text-xs text-ink-muted">
              {r.description}
            </span>
          )}
        </div>
      ),
    },
    {
      key: "code",
      header: "Mã",
      headerTooltip: "Mã định danh kỹ thuật duy nhất (không đổi sau khi tạo).",
      cell: (r) => <ClueTag label={r.code} color="jade" className="font-mono" />,
    },
    {
      key: "itemType",
      header: "Loại",
      headerTooltip: "Phân loại vật phẩm: Trang trí Đảo Di Sản (DECOR), Mô hình, Phiên bản số hoặc Huy hiệu.",
      cell: (r) => <ClueTag label={TYPE_LABELS[r.itemType] ?? r.itemType} color="gold" />,
    },
    {
      key: "placeable",
      header: "Đặt lên đảo",
      headerTooltip: "Bật cho vật phẩm DECOR / Mô hình để học viên có thể đặt lên ô đất trên Đảo Di Sản 2.5D hoặc mua trong Cửa hàng.",
      cell: (r) => (
        <div className="flex flex-col gap-1">
          {r.placeable ? (
            <>
              <ClueTag label="Có thể đặt" color="brand" className="w-fit" />
              {r.renderKey && (
                <code className="font-mono text-[11px] text-ink-muted">{r.renderKey}</code>
              )}
              <Link
                href="/island-shop"
                className="text-[11px] font-medium text-jade-dark hover:underline"
              >
                Cấu hình bán tại Shop →
              </Link>
            </>
          ) : (
            <span className="text-xs text-ink-muted">Không đặt lên đảo</span>
          )}
        </div>
      ),
    },
    {
      key: "rule",
      header: "Điều kiện mở khóa",
      headerTooltip: "Quy tắc tự động trao thưởng khi học viên hoàn thành bài học, sự kiện hoặc sưu tầm đủ bằng chứng.",
      cell: (r) =>
        r.rule ? (
          <div className="flex flex-col gap-0.5">
            <span className="text-xs font-medium text-ink">
              {RULE_LABELS[r.rule.ruleType] ?? r.rule.ruleType}
              {r.rule.threshold != null ? ` (≥ ${r.rule.threshold})` : ""}
            </span>
            <Link
              href={`/items/${r.id}#unlock-rule`}
              className="text-[11px] font-medium text-brand hover:underline"
            >
              Sửa điều kiện mở khóa →
            </Link>
          </div>
        ) : (
          <div className="flex flex-col gap-1">
            <span className="text-xs text-ink-muted">Chưa cấu hình</span>
            <Link
              href={`/items/${r.id}#unlock-rule`}
              className="inline-flex w-fit items-center rounded border border-brand/30 bg-brand/10 px-2 py-0.5 text-[11px] font-semibold text-brand transition-colors hover:bg-brand hover:text-surface-alt"
            >
              + Gắn vào bài học / sự kiện →
            </Link>
          </div>
        ),
    },
    {
      key: "active",
      header: "Trạng thái",
      headerTooltip: "Đang bật = hiển thị trong danh mục của học viên; Đã ẩn = tạm ngừng hiển thị.",
      cell: (r) => (
        <ClueTag
          label={r.active ? "Đang bật" : "Đã ẩn"}
          color={r.active ? "jade" : "gold"}
        />
      ),
    },
  ];

  const totalPages = Math.max(1, query.data?.totalPages ?? 0);
  const totalElements = query.data?.totalElements ?? (query.data?.content.length ?? 0);

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
      </PaperCard>

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
