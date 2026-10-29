"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useState } from "react";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminLessonSummary } from "@/lib/dto/lesson";
import type { LessonVersionSummary } from "@/lib/dto/version";
import { qk } from "@/lib/query-keys";
import { PaperCard } from "@/components/atoms/paper-card";
import { StampSeal } from "@/components/atoms/stamp-seal";
import { DataTable, type Column } from "@/components/data-table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";

const PAGE_SIZE = 20;

/**
 * /versions — lịch sử phiên bản bài học đã xuất bản.
 * Hỗ trợ xem toàn bộ phiên bản trên mọi bài học (GET /admin/lesson-versions)
 * hoặc lọc theo một bài học cụ thể (GET /admin/lessons/{id}/versions).
 */
export function VersionsBrowser({ initialLessonId }: { initialLessonId?: string }) {
  const [lessonId, setLessonId] = useState(initialLessonId ?? "");
  const [searchInput, setSearchInput] = useState("");
  const [q, setQ] = useState("");
  const [page, setPage] = useState(0);

  const lessonsQuery = useQuery({
    queryKey: qk.lessons.list({ size: 100 }),
    queryFn: () =>
      apiFetch<PageResponse<AdminLessonSummary>>(`/admin/lessons${toQuery({ size: 100 })}`),
  });
  const lessons = lessonsQuery.data?.content ?? [];
  const lessonsById = new Map(lessons.map((l) => [l.id, l]));

  const versionsQuery = useQuery({
    queryKey: qk.versions.list(lessonId || "ALL", { page, size: PAGE_SIZE, q: q || undefined }),
    queryFn: () =>
      lessonId
        ? apiFetch<PageResponse<LessonVersionSummary>>(
            `/admin/lessons/${lessonId}/versions${toQuery({ page, size: PAGE_SIZE })}`,
          )
        : apiFetch<PageResponse<LessonVersionSummary>>(
            `/admin/lesson-versions${toQuery({ page, size: PAGE_SIZE, q: q || undefined })}`,
          ),
    placeholderData: keepPreviousData,
  });

  const columns: Column<LessonVersionSummary>[] = [
    {
      key: "lessonTitle",
      header: "Bài học",
      cell: (r) => {
        const resolvedLessonId = r.lessonId ?? lessonId;
        const resolvedTitle =
          r.lessonTitle ??
          (resolvedLessonId ? lessonsById.get(resolvedLessonId)?.title : null) ??
          "Bài học";
        return resolvedLessonId ? (
          <Link href={`/lessons/${resolvedLessonId}`} className="font-medium text-ink hover:underline">
            {resolvedTitle}
          </Link>
        ) : (
          <span className="font-medium text-ink">{resolvedTitle}</span>
        );
      },
    },
    {
      key: "versionNo",
      header: "Phiên bản",
      cell: (r) => {
        const resolvedLessonId = r.lessonId ?? lessonId;
        const lessonMeta = resolvedLessonId ? lessonsById.get(resolvedLessonId) : undefined;
        return (
          <span className="inline-flex items-center gap-2 font-medium text-ink">
            <span>Phiên bản {r.versionNo}</span>
            {lessonMeta?.currentVersionId === r.id && (
              <>
                <span className="rounded bg-jade/15 px-1.5 py-0.5 text-[10px] font-medium text-jade-dark">
                  Đang phát hành
                </span>
                <StampSeal variant="success" label="ẤN" className="scale-75" />
              </>
            )}
          </span>
        );
      },
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
      cell: (r) => {
        const resolvedLessonId = r.lessonId ?? lessonId;
        if (!resolvedLessonId) return null;
        return (
          <Link
            href={`/versions/${resolvedLessonId}/${r.id}`}
            className="text-sm font-medium text-brand hover:underline"
          >
            Xem nội dung
          </Link>
        );
      },
    },
  ];

  const totalPages = Math.max(1, versionsQuery.data?.totalPages ?? 0);
  const totalElements = versionsQuery.data?.totalElements ?? 0;

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
            placeholder="Tìm theo tên bài học..."
            aria-label="Tìm kiếm phiên bản theo tên bài học"
            disabled={Boolean(lessonId)}
          />
          <Button type="submit" variant="secondary" disabled={Boolean(lessonId)}>
            Tìm
          </Button>
        </form>
        <Select
          value={lessonId}
          onChange={(e) => {
            setLessonId(e.target.value);
            setPage(0);
          }}
          aria-label="Chọn bài học"
          className="w-80"
        >
          <option value="">Tất cả bài học</option>
          {lessons.map((l) => (
            <option key={l.id} value={l.id}>
              {l.title}
            </option>
          ))}
        </Select>
      </PaperCard>

      <DataTable
        columns={columns}
        rows={versionsQuery.data?.content ?? []}
        rowKey={(r) => r.id}
        loading={versionsQuery.isPending}
        error={versionsQuery.error ?? undefined}
        onRetry={() => versionsQuery.refetch()}
        emptyTitle="Chưa có phiên bản nào"
        emptyDescription="Các bản chụp bài học đã xuất bản sẽ xuất hiện tại đây."
      />

      {totalElements > 0 && (
        <div className="flex items-center justify-between text-sm text-ink-muted">
          <span>
            Trang {page + 1} / {totalPages} ({totalElements} phiên bản)
          </span>
          <div className="flex gap-2">
            <Button variant="secondary" disabled={page <= 0} onClick={() => setPage(page - 1)}>
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
    </div>
  );
}
