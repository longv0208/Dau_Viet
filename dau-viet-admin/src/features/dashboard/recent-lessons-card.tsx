"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";

import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminLessonSummary } from "@/lib/dto/lesson";
import { qk } from "@/lib/query-keys";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { StatusChip } from "@/components/status-chip";

/**
 * "Bài học gần đây" — real data only. Uses sort=updatedAt,desc which is
 * whitelisted on GET /admin/lessons.
 */
export function RecentLessonsCard() {
  const query = useQuery({
    queryKey: qk.lessons.list({ size: 5, sort: "updatedAt,desc" }),
    queryFn: () =>
      apiFetch<PageResponse<AdminLessonSummary>>(
        `/admin/lessons${toQuery({ size: 5, sort: "updatedAt,desc" })}`,
      ),
  });

  const rows = query.data?.content ?? [];

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Bài học gần đây</CardTitle>
      </CardHeader>
      <CardContent>
        {query.isPending ? (
          <div className="flex flex-col gap-2">
            {Array.from({ length: 3 }).map((_, i) => (
              <Skeleton key={i} className="h-6 w-full" />
            ))}
          </div>
        ) : query.isError ? (
          <p className="text-sm text-error">Không tải được danh sách bài học.</p>
        ) : rows.length === 0 ? (
          <p className="text-sm text-ink-muted">Chưa có bài học nào.</p>
        ) : (
          <ul className="flex flex-col divide-y divide-border">
            {rows.map((lesson) => (
              <li key={lesson.id} className="flex items-center justify-between gap-3 py-2.5">
                <span className="truncate text-sm text-ink">{lesson.title}</span>
                <span className="flex shrink-0 items-center gap-2">
                  <span className="text-xs text-ink-muted">
                    {lesson.currentVersionId ? "Đã có phiên bản" : "Chưa xuất bản"}
                  </span>
                  <StatusChip status={lesson.status} />
                </span>
              </li>
            ))}
          </ul>
        )}
        {!query.isPending && !query.isError && rows.length > 0 && (
          <Link
            href="/lessons"
            className="mt-3 inline-block text-sm font-medium text-brand hover:underline"
          >
            Xem tất cả bài học
          </Link>
        )}
      </CardContent>
    </Card>
  );
}
