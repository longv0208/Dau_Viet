"use client";

import { useState } from "react";
import Link from "next/link";
import { keepPreviousData, useQuery } from "@tanstack/react-query";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminDossierSummary } from "@/lib/dto/gamification";
import { qk } from "@/lib/query-keys";
import { DataTable, type Column } from "@/components/data-table";
import { StatusChip } from "@/components/status-chip";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";

const TYPE_LABELS: Record<string, string> = {
  PERSON: "Nhân vật",
  LOCATION: "Địa điểm",
  ARTIFACT: "Hiện vật",
  CONTEXT: "Bối cảnh",
};

const PAGE_SIZE = 20;

/** /dossiers — thu vien ho so lich su, filter type/status + search + paging. */
export function DossiersTable() {
  const [page, setPage] = useState(0);
  const [type, setType] = useState("");
  const [status, setStatus] = useState("");
  const [q, setQ] = useState("");

  const params = {
    page,
    size: PAGE_SIZE,
    type: type || undefined,
    status: status || undefined,
    q: q || undefined,
  };
  const query = useQuery({
    queryKey: qk.dossiers.list(params),
    queryFn: () =>
      apiFetch<PageResponse<AdminDossierSummary>>(
        `/admin/dossiers${toQuery(params)}`,
      ),
    placeholderData: keepPreviousData,
  });

  const columns: Column<AdminDossierSummary>[] = [
    {
      key: "title",
      header: "Hồ sơ",
      cell: (d) => (
        <Link
          href={`/dossiers/${d.id}`}
          className="font-medium text-primary hover:underline"
        >
          {d.title}
        </Link>
      ),
    },
    {
      key: "code",
      header: "Mã",
      cell: (d) => <code className="text-xs">{d.canonicalCode}</code>,
    },
    {
      key: "type",
      header: "Loại",
      cell: (d) => TYPE_LABELS[d.dossierType] ?? d.dossierType,
    },
    {
      key: "status",
      header: "Trạng thái",
      cell: (d) => <StatusChip status={d.status} />,
    },
    {
      key: "v",
      header: "Version",
      cell: (d) => `v${d.dossierVersion}`,
    },
    {
      key: "events",
      header: "Sự kiện",
      cell: (d) => String(d.eventCount),
    },
    {
      key: "updated",
      header: "Cập nhật",
      cell: (d) => new Date(d.updatedAt).toLocaleString("vi-VN"),
    },
  ];

  const data = query.data;
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap gap-2">
        <Input
          placeholder="Tìm theo tên hoặc mã…"
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setPage(0);
          }}
          className="w-64"
        />
        <Select
          value={type}
          onChange={(e) => {
            setType(e.target.value);
            setPage(0);
          }}
          className="w-44"
        >
          <option value="">Mọi loại</option>
          {Object.entries(TYPE_LABELS).map(([v, l]) => (
            <option key={v} value={v}>
              {l}
            </option>
          ))}
        </Select>
        <Select
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setPage(0);
          }}
          className="w-44"
        >
          <option value="">Mọi trạng thái</option>
          <option value="DRAFT">Bản nháp</option>
          <option value="PUBLISHED">Đã xuất bản</option>
          <option value="ARCHIVED">Đã lưu trữ</option>
        </Select>
      </div>

      <DataTable
        columns={columns}
        rows={data?.content ?? []}
        rowKey={(d) => d.id}
        loading={query.isPending}
        error={query.error ?? undefined}
        onRetry={() => query.refetch()}
        emptyTitle="Chưa có hồ sơ"
        emptyDescription="Tạo hồ sơ đầu tiên để liên kết vào sự kiện."
      />

      {data && data.totalElements > 0 && (
        <div className="flex items-center justify-between text-sm text-ink-muted">
          <span>
            Trang {data.page + 1} / {Math.max(1, data.totalPages)} · {data.totalElements} hồ
            sơ
          </span>
          <div className="flex gap-2">
            <Button
              variant="secondary"
              disabled={data.page <= 0}
              onClick={() => setPage((p) => p - 1)}
            >
              Trước
            </Button>
            <Button
              variant="secondary"
              disabled={data.page >= Math.max(1, data.totalPages) - 1}
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
