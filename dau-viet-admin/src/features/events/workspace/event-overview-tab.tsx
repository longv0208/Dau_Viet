"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";

import { apiFetch, toQuery } from "@/lib/api-client";
import { parseReturnTo, withReturnTo } from "@/lib/return-to";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminLessonSummary } from "@/lib/dto/lesson";
import type { Evidence } from "@/lib/dto/evidence";
import type { AnimationSceneSummary } from "@/features/animations/animation-types";
import { qk } from "@/lib/query-keys";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { StatusChip } from "@/components/status-chip";
import { Button } from "@/components/ui/button";

import type { AdminEventDetail } from "@/lib/dto/event";

function useCount(key: readonly unknown[], url: string) {
  const q = useQuery({
    queryKey: key,
    queryFn: () => apiFetch<PageResponse<unknown>>(url),
    staleTime: 30_000,
  });
  return { total: q.data?.totalElements ?? null, isPending: q.isPending };
}

function StatCard({ label, value, href }: { label: string; value: number | null; href: string }) {
  return (
    <Link href={href} className="block rounded-lg border border-border bg-white p-4 transition-colors hover:bg-surface">
      <p className="text-sm text-ink-muted">{label}</p>
      <p className="mt-1 text-2xl font-bold text-ink">{value === null ? "—" : value}</p>
    </Link>
  );
}

/** Tab Tổng quan — stats, recent lessons, quick actions, next-step guidance. */
export function EventOverviewTab({ event }: { event: AdminEventDetail }) {
  const eventId = event.id;
  const returnTo = parseReturnTo(`/events/${eventId}?tab=lessons`);

  const lessons = useCount(qk.lessons.list({ eventId, size: 1 }),
    `/admin/lessons${toQuery({ eventId, size: 1 })}`);
  const evidences = useCount(qk.evidences.list({ eventId, size: 1 }),
    `/admin/evidences${toQuery({ eventId, size: 1 })}`);
  const animations = useCount(qk.animationScenes.list({ eventId, size: 1 }),
    `/admin/animation-scenes${toQuery({ eventId, size: 1 })}`);

  const recentLessons = useQuery({
    queryKey: qk.lessons.list({ eventId, size: 5 }),
    queryFn: () =>
      apiFetch<PageResponse<AdminLessonSummary>>(
        `/admin/lessons${toQuery({ eventId, size: 5, sort: "updatedAt,desc" })}`,
      ),
    staleTime: 30_000,
  });

  const pendingEvidence = useQuery({
    queryKey: qk.evidences.list({ eventId, size: 5, status: "DRAFT" }),
    queryFn: () =>
      apiFetch<PageResponse<Evidence>>(
        `/admin/evidences${toQuery({ eventId, size: 5, status: "DRAFT", sort: "updatedAt,desc" })}`,
      ),
    staleTime: 30_000,
  });

  const draftAnimations = useQuery({
    queryKey: qk.animationScenes.list({ eventId, size: 5, status: "DRAFT" }),
    queryFn: () =>
      apiFetch<PageResponse<AnimationSceneSummary>>(
        `/admin/animation-scenes${toQuery({ eventId, size: 5, status: "DRAFT", sort: "updatedAt,desc" })}`,
      ),
    staleTime: 30_000,
  });

  const newLessonHref = withReturnTo(
    `/lessons/new?event=${eventId}`,
    parseReturnTo(`/events/${eventId}?tab=lessons`),
  );

  return (
    <div className="flex flex-col gap-6">
      <p className="text-sm text-ink-muted">
        Chuẩn bị tư liệu và hoạt họa cho sự kiện, sau đó tạo một hoặc nhiều bài học
        và xuất bản từng bài khi sẵn sàng.
      </p>

      <div className="grid gap-3 sm:grid-cols-3">
        <StatCard label="Bài học" value={lessons.total} href={`/events/${eventId}?tab=lessons`} />
        <StatCard label="Bằng chứng" value={evidences.total} href={`/events/${eventId}?tab=hoc-lieu`} />
        <StatCard label="Hoạt họa" value={animations.total} href={`/events/${eventId}?tab=hoc-lieu`} />
      </div>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="text-base">Bài học gần đây</CardTitle>
          <Button asChild variant="secondary" size="sm">
            <Link href={`/events/${eventId}?tab=lessons`}>Xem tất cả</Link>
          </Button>
        </CardHeader>
        <CardContent>
          {recentLessons.isPending && <Skeleton className="h-24 w-full" />}
          {recentLessons.data && recentLessons.data.content.length === 0 && (
            <p className="text-sm text-ink-muted">
              Chưa có bài học nào — tạo bài học đầu tiên để bắt đầu soạn nội dung.
            </p>
          )}
          <ul className="flex flex-col gap-2">
            {(recentLessons.data?.content ?? []).map((l) => (
              <li key={l.id} className="flex items-center justify-between rounded-md border border-border px-3 py-2">
                <div className="min-w-0">
                  <Link
                    href={withReturnTo(`/lessons/${l.id}`, returnTo)}
                    className="truncate font-medium text-ink hover:underline"
                  >
                    {l.title}
                  </Link>
                </div>
                <div className="flex items-center gap-3">
                  <StatusChip status={l.status} />
                  <Link
                    href={withReturnTo(`/lessons/${l.id}/publish`, returnTo)}
                    className="text-sm text-primary hover:underline"
                  >
                    Xuất bản
                  </Link>
                </div>
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>

      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Bằng chứng chưa phê duyệt</CardTitle>
          </CardHeader>
          <CardContent>
            {pendingEvidence.isPending && <Skeleton className="h-16 w-full" />}
            {pendingEvidence.data && pendingEvidence.data.content.length === 0 && (
              <p className="text-sm text-ink-muted">Không có bằng chứng nào đang chờ duyệt.</p>
            )}
            <ul className="flex flex-col gap-1.5">
              {(pendingEvidence.data?.content ?? []).map((e) => (
                <li key={e.id}>
                  <Link
                    href={withReturnTo(`/evidence/${e.id}`, parseReturnTo(`/events/${eventId}?tab=hoc-lieu`))}
                    className="text-sm text-primary hover:underline"
                  >
                    {e.title}
                  </Link>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Hoạt họa chưa xuất bản</CardTitle>
          </CardHeader>
          <CardContent>
            {draftAnimations.isPending && <Skeleton className="h-16 w-full" />}
            {draftAnimations.data && draftAnimations.data.content.length === 0 && (
              <p className="text-sm text-ink-muted">Tất cả hoạt họa đã được xuất bản.</p>
            )}
            <ul className="flex flex-col gap-1.5">
              {(draftAnimations.data?.content ?? []).map((s) => (
                <li key={s.id}>
                  <Link
                    href={withReturnTo(`/animations/${s.id}/edit`, parseReturnTo(`/events/${eventId}?tab=hoc-lieu`))}
                    className="text-sm text-primary hover:underline"
                  >
                    {s.title}
                  </Link>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      </div>

      <div className="flex flex-wrap gap-2">
        <Button asChild>
          <Link href={newLessonHref}>+ Tạo bài học mới</Link>
        </Button>
        <Button asChild variant="secondary">
          <Link href={withReturnTo(`/evidence/new?event=${eventId}`, parseReturnTo(`/events/${eventId}?tab=hoc-lieu`))}>
            + Thêm bằng chứng
          </Link>
        </Button>
        <Button asChild variant="secondary">
          <Link href={`/events/${eventId}?tab=hoc-lieu`}>+ Tải hoạt họa lên</Link>
        </Button>
      </div>
    </div>
  );
}
