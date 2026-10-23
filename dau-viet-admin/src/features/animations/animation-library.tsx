"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useState } from "react";
import { useRouter } from "next/navigation";

import { DataTable, type Column } from "@/components/data-table";
import { StatusChip } from "@/components/status-chip";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { qk } from "@/lib/query-keys";

import { animationApi } from "./animation-api";
import type { AnimationSceneSummary } from "./animation-types";

const STATUS_LABELS: Record<string, string> = {
  "": "Tất cả trạng thái",
  DRAFT: "Bản nháp",
  PUBLISHED: "Đã xuất bản",
  ARCHIVED: "Đã lưu trữ",
};

const RENDERER_LABELS: Record<string, string> = {
  RIVER_TIDE: "Sông & thủy triều",
  JOURNEY_MAP: "Hành trình bản đồ",
};

/**
 * Screen A — Thư viện hoạt họa: tìm kiếm/lọc/phân trang + hành động
 * (sửa, nhân bản, lưu trữ, xuất bản nhanh qua trang chi tiết).
 */
export function AnimationLibrary() {
  const router = useRouter();
  const qc = useQueryClient();
  const [q, setQ] = useState("");
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(0);

  const query = useQuery({
    queryKey: qk.animationScenes.list({ page, size: 20, status, q }),
    queryFn: () => animationApi.listScenes({ page, size: 20, status, q }),
  });
  const templates = useQuery({
    queryKey: qk.animationTemplates.list({ enabled: true }),
    queryFn: () => animationApi.listTemplates({ enabled: true, size: 100 }),
  });
  const templateById = new Map(
    (templates.data?.content ?? []).map((t) => [t.id, t] as const),
  );

  const invalidate = () =>
    qc.invalidateQueries({ queryKey: ["animation-scenes"] });

  const duplicate = useMutation({
    mutationFn: (id: string) => animationApi.duplicateScene(id),
    onSuccess: (scene) => {
      invalidate();
      router.push(`/animations/${scene.id}/edit`);
    },
  });
  const archive = useMutation({
    mutationFn: (id: string) => animationApi.archiveScene(id),
    onSuccess: invalidate,
  });
  const actionError = duplicate.error ?? archive.error;

  const rows = query.data?.content ?? [];

  const columns: Column<AnimationSceneSummary>[] = [
    {
      key: "title",
      header: "Tên cảnh",
      cell: (r) => (
        <Link
          href={`/animations/${r.id}/edit`}
          className="font-medium text-primary hover:underline"
        >
          {r.title}
        </Link>
      ),
    },
    {
      key: "template",
      header: "Kiểu cảnh",
      cell: (r) => (
        <span className="text-ink-muted">
          {RENDERER_LABELS[templateById.get(r.templateId)?.rendererCode ?? ""] ??
            templateById.get(r.templateId)?.name ??
            "—"}
        </span>
      ),
    },
    {
      key: "status",
      header: "Trạng thái",
      cell: (r) => <StatusChip status={r.status} />,
    },
    {
      key: "version",
      header: "Phiên bản",
      cell: (r) =>
        r.currentVersionNo != null ? (
          <Link
            href={`/animations/${r.id}/versions`}
            className="text-primary hover:underline"
          >
            v{r.currentVersionNo}
          </Link>
        ) : (
          <span className="text-ink-muted">—</span>
        ),
    },
    {
      key: "actions",
      header: "Thao tác",
      cell: (r) => (
        <div className="flex flex-wrap gap-2">
          <Button asChild variant="outline" size="sm">
            <Link href={`/animations/${r.id}/edit`}>Soạn</Link>
          </Button>
          <Button
            variant="outline"
            size="sm"
            disabled={duplicate.isPending}
            onClick={() => duplicate.mutate(r.id)}
          >
            Nhân bản
          </Button>
          {r.status !== "ARCHIVED" && (
            <Button
              variant="outline"
              size="sm"
              disabled={archive.isPending}
              onClick={() => {
                if (window.confirm(`Lưu trữ cảnh "${r.title}"?`)) {
                  archive.mutate(r.id);
                }
              }}
            >
              Lưu trữ
            </Button>
          )}
        </div>
      ),
    },
  ];

  const totalPages = query.data?.totalPages ?? 0;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3">
        <Input
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setPage(0);
          }}
          placeholder="Tìm theo tên cảnh…"
          className="max-w-xs"
          aria-label="Tìm theo tên cảnh"
        />
        <Select
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setPage(0);
          }}
          className="w-48"
          aria-label="Lọc theo trạng thái"
        >
          {Object.entries(STATUS_LABELS).map(([v, l]) => (
            <option key={v} value={v}>
              {l}
            </option>
          ))}
        </Select>
      </div>

      {actionError && (
        <p role="alert" className="rounded-md border border-error/40 bg-error/5 px-3 py-2 text-xs text-error">
          Thao tác thất bại: {actionError.message}
        </p>
      )}

      <DataTable
        columns={columns}
        rows={rows}
        rowKey={(r) => r.id}
        loading={query.isPending}
        error={query.error ?? undefined}
        onRetry={() => query.refetch()}
        emptyTitle="Chưa có hoạt họa nào"
        emptyDescription='Bấm "Tạo hoạt họa mới" để bắt đầu soạn cảnh minh họa đầu tiên.'
      />

      {totalPages > 1 && (
        <div className="flex items-center gap-3 text-sm text-ink-muted">
          <Button
            variant="outline"
            size="sm"
            disabled={page === 0}
            onClick={() => setPage((p) => p - 1)}
          >
            ← Trước
          </Button>
          <span>
            Trang {page + 1}/{totalPages}
          </span>
          <Button
            variant="outline"
            size="sm"
            disabled={page + 1 >= totalPages}
            onClick={() => setPage((p) => p + 1)}
          >
            Sau →
          </Button>
        </div>
      )}
    </div>
  );
}
