"use client";

import { useQuery } from "@tanstack/react-query";

import { DataTable, type Column } from "@/components/data-table";
import { qk } from "@/lib/query-keys";

import { animationApi } from "./animation-api";
import type { SceneVersionSummary } from "./animation-types";

const COLUMNS: Column<SceneVersionSummary>[] = [
  {
    key: "versionNo",
    header: "Phiên bản",
    cell: (r) => <span className="font-medium">v{r.versionNo}</span>,
  },
  {
    key: "renderer",
    header: "Bộ vẽ",
    cell: (r) => (
      <code className="text-xs">
        {r.rendererCode} v{r.rendererVersion}
      </code>
    ),
  },
  {
    key: "publishedAt",
    header: "Xuất bản lúc",
    cell: (r) => new Date(r.publishedAt).toLocaleString("vi-VN"),
  },
  {
    key: "checksum",
    header: "Checksum",
    cell: (r) => (
      <code className="text-xs text-ink-muted">
        {r.manifestChecksum.slice(0, 12)}…
      </code>
    ),
  },
];

/** Trang phiên bản — list non-paginated List<SceneVersionSummary>. */
export function SceneVersionsTable({ sceneId }: { sceneId: string }) {
  const query = useQuery({
    queryKey: qk.animationScenes.versions(sceneId),
    queryFn: () => animationApi.listVersions(sceneId),
  });

  return (
    <DataTable
      columns={COLUMNS}
      rows={query.data ?? []}
      rowKey={(r) => r.id}
      loading={query.isPending}
      error={query.error ?? undefined}
      onRetry={() => query.refetch()}
      emptyTitle="Chưa có phiên bản nào"
      emptyDescription="Xuất bản cảnh lần đầu để tạo phiên bản v1."
    />
  );
}
