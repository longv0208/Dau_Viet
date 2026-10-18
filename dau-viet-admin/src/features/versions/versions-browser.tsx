"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useState } from "react";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminLessonSummary } from "@/lib/dto/lesson";
import type { LessonVersionSummary } from "@/lib/dto/version";
import { qk } from "@/lib/query-keys";
import { DataTable, type Column } from "@/components/data-table";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";

const PAGE_SIZE = 20;

/**
 * /versions — chọn một bài học rồi xem lịch sử phiên bản đã xuất bản.
 * Backend exposes versions per-lesson only (GET /admin/lessons/{id}/versions),
 * so there is no global list — the picker is the entry point.
 */
export function VersionsBrowser({ initialLessonId }: { initialLessonId?: string }) {
  const [lessonId, setLessonId] = useState(initialLessonId ?? "");
  const [page, setPage] = useState(0);

  const lessonsQuery = useQuery({
    queryKey: qk.lessons.list({ size: 100 }),
    queryFn: () =>
      apiFetch<PageResponse<AdminLessonSummary>>(`/admin/lessons${toQuery({ size: 100 })}`),
  });
  const lessons = lessonsQuery.data?.content ?? [];
  const selectedLesson = lessons.find((l) => l.id === lessonId);

  const versionsQuery = useQuery({
    queryKey: qk.versions.list(lessonId, { page, size: PAGE_SIZE }),
    queryFn: () =>
      apiFetch<PageResponse<LessonVersionSummary>>(
        `/admin/lessons/${lessonId}/versions${toQuery({ page, size: PAGE_SIZE })}`,
      ),
    enabled: Boolean(lessonId),
    placeholderData: keepPreviousData,
  });

  const columns: Column<LessonVersionSummary>[] = [
    {
      key: "versionNo",
      header: "Phiên bản",
      cell: (r) => (
        <span className="font-medium text-ink">
          Phiên bản {r.versionNo}
          {selectedLesson?.currentVersionId === r.id && (
            <span className="ml-2 rounded bg-success/15 px-1.5 py-0.5 text-[10px] font-medium text-success">
              Đang phát hành
            </span>
          )}
        </span>
      ),
    },
    {
      key: "publishedAt",
      header: "Thời điểm xuất bản",
      cell: (r) => (
        <span className="text-ink">
          {new Date(r.publishedAt).toLocaleString("vi-VN")}
        </span>
      ),
    },
    {
      key: "publishedBy",
      header: "Người xuất bản",
      cell: (r) => <span className="text-xs text-ink-muted">{r.publishedBy}</span>,
    },
    {
      key: "actions",
      header: "",
      cell: (r) => (
        <Link
          href={`/versions/${lessonId}/${r.id}`}
          className="text-sm text-primary hover:underline"
        >
          Xem nội dung
        </Link>
      ),
    },
  ];

  const totalPages = versionsQuery.data?.totalPages ?? 0;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3">
        <Select
          value={lessonId}
          onChange={(e) => {
            setLessonId(e.target.value);
            setPage(0);
          }}
          aria-label="Chọn bài học"
          className="w-80"
        >
          <option value="">— Chọn bài học —</option>
          {lessons.map((l) => (
            <option key={l.id} value={l.id}>
              {l.title}
            </option>
          ))}
        </Select>
        {lessonsQuery.isPending && (
          <span className="text-xs text-ink-muted">Đang tải danh sách bài học...</span>
        )}
        {lessonsQuery.isError && (
          <span className="text-xs text-error">
            Không tải được danh sách bài học — thử tải lại trang.
          </span>
        )}
      </div>

      {!lessonId ? (
        <p className="text-sm text-ink-muted">
          Chọn một bài học ở trên để xem toàn bộ phiên bản đã xuất bản của nó.
        </p>
      ) : (
        <>
          <DataTable
            columns={columns}
            rows={versionsQuery.data?.content ?? []}
            rowKey={(r) => r.id}
            loading={versionsQuery.isPending}
            error={versionsQuery.error ?? undefined}
            onRetry={() => versionsQuery.refetch()}
            emptyTitle="Chưa có phiên bản nào"
            emptyDescription="Bài học này chưa được xuất bản lần nào."
          />
          {totalPages > 1 && (
            <div className="flex items-center justify-between text-sm text-ink-muted">
              <span>
                Trang {page + 1} / {totalPages} ({versionsQuery.data?.totalElements ?? 0} phiên
                bản)
              </span>
              <div className="flex gap-2">
                <Button variant="secondary" disabled={page === 0} onClick={() => setPage(page - 1)}>
                  Trước
                </Button>
                <Button
                  variant="secondary"
                  disabled={page + 1 >= totalPages}
                  onClick={() => setPage(page + 1)}
                >
                  Sau
                </Button>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
