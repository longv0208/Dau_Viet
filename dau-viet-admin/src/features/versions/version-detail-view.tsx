"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";

import { apiFetch } from "@/lib/api-client";
import type { LessonVersionDetail } from "@/lib/dto/version";
import { qk } from "@/lib/query-keys";
import { Button } from "@/components/ui/button";
import { ErrorState } from "@/components/error-state";
import { Skeleton } from "@/components/ui/skeleton";

import { LessonContentView } from "../lessons/preview/lesson-content-view";

/**
 * Read-only view of one immutable published version — same learner-facing
 * rendering as the draft preview, plus the version's metadata header.
 */
export function VersionDetailView({
  lessonId,
  versionId,
}: {
  lessonId: string;
  versionId: string;
}) {
  const query = useQuery({
    queryKey: qk.versions.detail(lessonId, versionId),
    queryFn: () =>
      apiFetch<LessonVersionDetail>(`/admin/lessons/${lessonId}/versions/${versionId}`),
    enabled: Boolean(lessonId && versionId),
  });

  if (query.isPending) {
    return (
      <div className="mx-auto flex w-full max-w-[390px] flex-col gap-3">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-[30rem] w-full rounded-3xl" />
      </div>
    );
  }
  if (query.isError) {
    return <ErrorState error={query.error} onRetry={() => query.refetch()} />;
  }

  const v = query.data;
  if (!v) return null;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3">
        <p className="rounded-md bg-success/10 px-3 py-1.5 text-xs font-medium text-success">
          Phiên bản {v.versionNo} — đã xuất bản lúc{" "}
          {new Date(v.publishedAt).toLocaleString("vi-VN")} · bản chụp không thể sửa
        </p>
        <Button asChild variant="secondary" size="sm" className="ml-auto">
          <Link href={`/versions?lesson=${lessonId}`}>← Danh sách phiên bản</Link>
        </Button>
      </div>

      <LessonContentView content={v.snapshot} />
    </div>
  );
}
