"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useState } from "react";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { LessonTemplate } from "@/lib/dto/lesson";
import { qk } from "@/lib/query-keys";
import { ClueTag } from "@/components/atoms/clue-tag";
import { PaperCard } from "@/components/atoms/paper-card";
import { DataTable, type Column } from "@/components/data-table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
const PAGE_SIZE = 20;

const COLUMNS: Column<LessonTemplate>[] = [
  {
    key: "name",
    header: "Tên mẫu",
    cell: (r) => (
      <Link href={`/templates/${r.id}`} className="font-medium text-brand hover:underline">
        {r.name}
      </Link>
    ),
  },
  { key: "code", header: "Mã", cell: (r) => <ClueTag label={r.code} color="jade" className="font-mono" /> },
  {
    key: "description",
    header: "Mô tả",
    cell: (r) => <span className="text-ink-muted">{r.description}</span>,
  },
  {
    key: "enabled",
    header: "Trạng thái",
    cell: (r) => (
      <ClueTag
        label={r.enabled ? "Đang bật" : "Đã tắt"}
        color={r.enabled ? "jade" : "gold"}
      />
    ),
  },
];

/**
 * /templates — danh mục mẫu bài học có phân trang & bộ lọc từ GET /admin/lesson-templates?page=...
 */
export function TemplatesTable() {
  const [searchInput, setSearchInput] = useState("");
  const [q, setQ] = useState("");
  const [enabledFilter, setEnabledFilter] = useState("");
  const [page, setPage] = useState(0);

  const enabled =
    enabledFilter === "true" ? true : enabledFilter === "false" ? false : undefined;

  const query = useQuery({
    queryKey: qk.templates.list({
      page,
      size: PAGE_SIZE,
      enabled,
      q: q || undefined,
    }),
    queryFn: () =>
      apiFetch<PageResponse<LessonTemplate> | LessonTemplate[]>(
        `/admin/lesson-templates${toQuery({
          page,
          size: PAGE_SIZE,
          enabled: enabledFilter || undefined,
          q: q || undefined,
        })}`,
      ),
    placeholderData: keepPreviousData,
  });

  const rows = Array.isArray(query.data)
    ? query.data
    : (query.data?.content ?? []);
  const totalElements = Array.isArray(query.data)
    ? query.data.length
    : (query.data?.totalElements ?? rows.length);
  const totalPages = Math.max(
    1,
    Array.isArray(query.data) ? 1 : (query.data?.totalPages ?? 1),
  );

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
            placeholder="Tìm theo tên, mã hoặc mô tả mẫu..."
            aria-label="Tìm kiếm mẫu bài học"
          />
          <Button type="submit" variant="secondary">
            Tìm
          </Button>
        </form>
        <Select
          value={enabledFilter}
          onChange={(e) => {
            setEnabledFilter(e.target.value);
            setPage(0);
          }}
          aria-label="Lọc theo trạng thái"
          className="w-44"
        >
          <option value="">Mọi trạng thái</option>
          <option value="true">Đang bật</option>
          <option value="false">Đã tắt</option>
        </Select>
      </PaperCard>

      <DataTable
        columns={COLUMNS}
        rows={rows}
        rowKey={(r) => r.id}
        loading={query.isPending}
        error={query.error ?? undefined}
        onRetry={() => query.refetch()}
        emptyTitle="Chưa có mẫu bài học nào"
        emptyDescription="Các mẫu hoạt động chuẩn sẽ xuất hiện tại đây."
      />

      {totalElements > 0 && (
        <div className="flex items-center justify-between text-sm text-ink-muted">
          <span>
            Trang {page + 1} / {totalPages} ({totalElements} mẫu bài học)
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
