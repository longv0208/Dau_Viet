"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronRight } from "lucide-react";
import { Fragment } from "react";

import { apiFetch } from "@/lib/api-client";
import type { AdminEventSummary } from "@/lib/dto/event";
import type { AdminLessonDetail } from "@/lib/dto/lesson";
import { qk } from "@/lib/query-keys";

/** Route segment → Vietnamese crumb label. */
const CRUMB_LABELS: Record<string, string> = {
  dashboard: "Tổng quan",
  events: "Sự kiện",
  "learning-path": "Bản đồ Dấu Ấn",
  edit: "Thiết kế",
  lessons: "Bài học",
  evidence: "Bằng chứng",
  templates: "Mẫu bài học",
  assets: "Thư viện media",
  animations: "Hoạt họa lịch sử",
  versions: "Phiên bản",
  items: "Vật phẩm thưởng",
  builder: "Trình soạn",
  preview: "Xem trước",
  publish: "Xuất bản",
};

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Derives breadcrumbs from the pathname; UUID segments resolve to entity titles
 * for events/lessons (workspace context), other ids fall back to "Chi tiết". */
export function Breadcrumbs() {
  const pathname = usePathname() ?? "/";
  const segments = pathname.split("/").filter(Boolean);

  const eventId =
    segments[0] === "events" && segments[1] && UUID_RE.test(segments[1])
      ? segments[1]
      : null;
  const lessonId =
    segments[0] === "lessons" && segments[1] && UUID_RE.test(segments[1])
      ? segments[1]
      : null;

  const eventQuery = useQuery({
    queryKey: qk.events.detail(eventId ?? "none"),
    queryFn: () => apiFetch<AdminEventSummary>(`/admin/events/${eventId}`),
    enabled: Boolean(eventId),
    staleTime: 60_000,
  });
  const lessonQuery = useQuery({
    queryKey: qk.lessons.detail(lessonId ?? "none"),
    queryFn: () => apiFetch<AdminLessonDetail>(`/admin/lessons/${lessonId}`),
    enabled: Boolean(lessonId),
    staleTime: 60_000,
  });

  if (segments.length === 0) return null;

  const resolvedLabel = (seg: string): string | null => {
    if (seg === eventId) return eventQuery.data?.title ?? "Chi tiết";
    if (seg === lessonId) return lessonQuery.data?.title ?? "Chi tiết";
    return null;
  };

  let acc = "";
  return (
    <nav aria-label="Breadcrumb">
      <ol className="flex items-center gap-1 text-sm text-ink-muted">
        {segments.map((seg, i) => {
          acc += `/${seg}`;
          const isIdLike = UUID_RE.test(seg) || seg.length > 24;
          const label =
            resolvedLabel(seg) ?? CRUMB_LABELS[seg] ?? (isIdLike ? "Chi tiết" : seg);
          const isLast = i === segments.length - 1;
          return (
            <Fragment key={acc}>
              {i > 0 && <ChevronRight className="size-3.5" aria-hidden />}
              <li aria-current={isLast ? "page" : undefined}>
                {isLast ? (
                  <span className="font-medium text-ink">{label}</span>
                ) : (
                  <Link href={acc} className="hover:text-brand hover:underline">
                    {label}
                  </Link>
                )}
              </li>
            </Fragment>
          );
        })}
      </ol>
    </nav>
  );
}
