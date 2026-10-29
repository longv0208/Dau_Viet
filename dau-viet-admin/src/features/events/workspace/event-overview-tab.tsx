"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { BookOpen, Film, ScrollText, type LucideIcon } from "lucide-react";

import { apiFetch, toQuery } from "@/lib/api-client";
import { parseReturnTo, withReturnTo } from "@/lib/return-to";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminLessonSummary } from "@/lib/dto/lesson";
import type { Evidence } from "@/lib/dto/evidence";
import type { AnimationSceneSummary } from "@/features/animations/animation-types";
import { qk } from "@/lib/query-keys";
import { PaperCard } from "@/components/atoms/paper-card";
import { SectionDivider } from "@/components/atoms/section-divider";
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

function StatCard({
  label,
  value,
  href,
  icon: Icon,
  iconColor = "text-jade",
}: {
  label: string;
  value: number | null;
  href: string;
  icon: LucideIcon;
  iconColor?: string;
}) {
  return (
    <Link href={href} className="block">
      <PaperCard interactive className="flex items-center justify-between p-4">
        <div>
          <p className="text-sm text-ink-muted">{label}</p>
          <p className="mt-1 font-pixel text-2xl text-chapter">{value === null ? "—" : value}</p>
        </div>
        <Icon className={`size-7 shrink-0 ${iconColor}`} aria-hidden />
      </PaperCard>
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
        <StatCard
          label="Bài học"
          value={lessons.total}
          href={`/events/${eventId}?tab=lessons`}
          icon={BookOpen}
          iconColor="text-brand"
        />
        <StatCard
          label="Bằng chứng"
          value={evidences.total}
          href={`/events/${eventId}?tab=hoc-lieu`}
          icon={ScrollText}
          iconColor="text-jade"
        />
        <StatCard
          label="Hoạt họa"
          value={animations.total}
          href={`/events/${eventId}?tab=hoc-lieu`}
          icon={Film}
          iconColor="text-brand"
        />
      </div>

      <PaperCard className="p-5">
        <SectionDivider
          eyebrow="NỘI DUNG"
          title="Bài học gần đây"
          action={
            <Button asChild variant="secondary" size="sm">
              <Link href={`/events/${eventId}?tab=lessons`}>Xem tất cả</Link>
            </Button>
          }
          className="mb-4"
        />
        <div>
          {recentLessons.isPending && <Skeleton className="h-24 w-full" />}
          {recentLessons.data && recentLessons.data.content.length === 0 && (
            <p className="text-sm text-ink-muted">
              Chưa có bài học nào — tạo bài học đầu tiên để bắt đầu soạn nội dung.
            </p>
          )}
          <ul className="flex flex-col gap-2">
            {(recentLessons.data?.content ?? []).map((l) => (
              <li key={l.id} className="flex items-center justify-between rounded-md border border-border bg-surface px-3 py-2">
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
                    className="text-sm font-medium text-brand hover:underline"
                  >
                    Xuất bản
                  </Link>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </PaperCard>

      <div className="grid gap-4 md:grid-cols-2">
        <PaperCard className="p-5">
          <SectionDivider
            eyebrow="CHỜ DUYỆT"
            eyebrowColor="gold"
            title="Bằng chứng chưa phê duyệt"
            className="mb-4"
          />
          <div>
            {pendingEvidence.isPending && <Skeleton className="h-16 w-full" />}
            {pendingEvidence.data && pendingEvidence.data.content.length === 0 && (
              <p className="text-sm text-ink-muted">Không có bằng chứng nào đang chờ duyệt.</p>
            )}
            <ul className="flex flex-col gap-1.5">
              {(pendingEvidence.data?.content ?? []).map((e) => (
                <li key={e.id}>
                  <Link
                    href={withReturnTo(`/evidence/${e.id}`, parseReturnTo(`/events/${eventId}?tab=hoc-lieu`))}
                    className="text-sm font-medium text-brand hover:underline"
                  >
                    {e.title}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </PaperCard>

        <PaperCard className="p-5">
          <SectionDivider
            eyebrow="BẢN NHÁP"
            eyebrowColor="jade"
            title="Hoạt họa chưa xuất bản"
            className="mb-4"
          />
          <div>
            {draftAnimations.isPending && <Skeleton className="h-16 w-full" />}
            {draftAnimations.data && draftAnimations.data.content.length === 0 && (
              <p className="text-sm text-ink-muted">Tất cả hoạt họa đã được xuất bản.</p>
            )}
            <ul className="flex flex-col gap-1.5">
              {(draftAnimations.data?.content ?? []).map((s) => (
                <li key={s.id}>
                  <Link
                    href={withReturnTo(`/animations/${s.id}/edit`, parseReturnTo(`/events/${eventId}?tab=hoc-lieu`))}
                    className="text-sm font-medium text-brand hover:underline"
                  >
                    {s.title}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </PaperCard>
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
