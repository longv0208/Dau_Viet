"use client";

import type { AdminCompletionPolicy } from "@/lib/dto/gamification";
import { DataTable, type Column } from "@/components/data-table";
import { StatusChip } from "@/components/status-chip";
import { Button } from "@/components/ui/button";

/** Bảng lịch sử policy version — mới nhất trước (backend đã sort). */
export function PolicyList({
  rows,
  loading,
  error,
  onRetry,
  onEdit,
  onPublish,
  publishingId,
}: {
  rows: AdminCompletionPolicy[];
  loading: boolean;
  error?: unknown;
  onRetry: () => void;
  onEdit: (p: AdminCompletionPolicy) => void;
  onPublish: (p: AdminCompletionPolicy) => void;
  publishingId: string | null;
}) {
  const columns: Column<AdminCompletionPolicy>[] = [
    { key: "v", header: "Version", cell: (p) => `v${p.policyVersion}` },
    {
      key: "status",
      header: "Trạng thái",
      cell: (p) => <StatusChip status={p.status} />,
    },
    {
      key: "req",
      header: "Bắt buộc",
      cell: (p) => String(p.requiredLessonIds.length),
    },
    {
      key: "opt",
      header: "Tuỳ chọn",
      cell: (p) => String(p.optionalLessonIds.length),
    },
    {
      key: "th",
      header: "Ngưỡng mastered",
      cell: (p) => (p.masteryThreshold == null ? "—" : `${p.masteryThreshold}%`),
    },
    {
      key: "pub",
      header: "Xuất bản",
      cell: (p) =>
        p.publishedAt ? new Date(p.publishedAt).toLocaleString("vi-VN") : "—",
    },
    {
      key: "act",
      header: "",
      cell: (p) =>
        p.status === "DRAFT" ? (
          <div className="flex gap-2">
            <Button variant="secondary" onClick={() => onEdit(p)}>
              Sửa
            </Button>
            <Button
              disabled={publishingId === p.id}
              onClick={() => onPublish(p)}
            >
              {publishingId === p.id ? "Đang xuất bản…" : "Xuất bản"}
            </Button>
          </div>
        ) : null,
    },
  ];

  return (
    <DataTable
      columns={columns}
      rows={rows}
      rowKey={(p) => p.id}
      loading={loading}
      error={error}
      onRetry={onRetry}
      emptyTitle="Chưa có chính sách"
      emptyDescription="Tạo bản nháp đầu tiên để cấu hình điều kiện hoàn thành sự kiện."
    />
  );
}
