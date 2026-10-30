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
          <p className="mt-1 font-display text-2xl font-bold tabular-nums text-chapter">{value === null ? "—" : value}</p>
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
      {event.status === "DRAFT" && (
        <div
          role="status"
          className="rounded-md border border-warning/40 bg-warning/15 px-4 py-3 text-sm text-ink"
        >
          <strong>Lưu ý thứ tự xuất bản:</strong> Sự kiện đang ở trạng thái <strong>Bản nháp (DRAFT)</strong>. Hãy bấm nút <strong>&ldquo;Xuất bản sự kiện&rdquo;</strong> ở góc trên bên phải trước khi xuất bản Bài học, Địa điểm bản đồ hoặc Chính sách hoàn thành sự kiện.
        </div>
      )}
      <PaperCard className="border-l-4 border-l-brand bg-surface-alt p-4">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
          <div>
            <p className="font-sans text-xs font-bold uppercase tracking-wider text-brand">
              Quy trình biên tập trong Không gian Sự kiện
            </p>
            <p className="mt-0.5 text-sm text-ink-muted">
              Thực hiện lần lượt 4 bước ngay trên các tab bên trên để hoàn thiện trọn vẹn sự kiện lịch sử này:
            </p>
          </div>
          <Link
            href="/learning-path"
            className="text-xs font-semibold text-jade-dark hover:underline"
          >
            Đưa sự kiện lên Bản đồ Dấu Ấn →
          </Link>
        </div>
        <ol className="grid gap-2.5 sm:grid-cols-2 lg:grid-cols-4">
          <li className="rounded-md border border-border bg-surface p-3">
            <p className="text-xs font-bold text-chapter">Bước 1 · Thông tin &amp; Địa điểm</p>
            <p className="mt-1 text-xs text-ink-muted">
              Khai báo thời kỳ, năm, câu hỏi trung tâm, ghim di tích và bấm <strong>Xuất bản sự kiện</strong> (góc trên bên phải) trước khi xuất bản Bài học, Địa điểm hoặc Chính sách hoàn thành.
            </p>
            <Link
              href={`/events/${eventId}?tab=info`}
              className="mt-2 inline-block text-xs font-semibold text-brand hover:underline"
            >
              Mở tab Thông tin &amp; địa điểm →
            </Link>
          </li>
          <li className="rounded-md border border-border bg-surface p-3">
            <p className="text-xs font-bold text-chapter">Bước 2 · Học liệu &amp; Bằng chứng</p>
            <p className="mt-1 text-xs text-ink-muted">
              Thêm tư liệu bằng chứng ({evidences.total ?? 0}) và cảnh hoạt họa HTML ({animations.total ?? 0}).
            </p>
            <Link
              href={`/events/${eventId}?tab=hoc-lieu`}
              className="mt-2 inline-block text-xs font-semibold text-brand hover:underline"
            >
              Mở tab Học liệu →
            </Link>
          </li>
          <li className="rounded-md border border-border bg-surface p-3">
            <p className="text-xs font-bold text-chapter">Bước 3 · Bài học điều tra</p>
            <p className="mt-1 text-xs text-ink-muted">
              Soạn hoạt động học tập ({lessons.total ?? 0} bài học), xem trước và xuất bản.
            </p>
            <Link
              href={`/events/${eventId}?tab=lessons`}
              className="mt-2 inline-block text-xs font-semibold text-brand hover:underline"
            >
              Mở tab Bài học →
            </Link>
          </li>
          <li className="rounded-md border border-border bg-surface p-3">
            <p className="text-xs font-bold text-chapter">Bước 4 · Gamification &amp; Hồ sơ</p>
            <p className="mt-1 text-xs text-ink-muted">
              Liên kết Hồ sơ lịch sử và chính sách hoàn thành sự kiện.
            </p>
            <Link
              href={`/events/${eventId}?tab=gamification`}
              className="mt-2 inline-block text-xs font-semibold text-brand hover:underline"
            >
              Mở tab Gamification →
            </Link>
          </li>
        </ol>
      </PaperCard>
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
