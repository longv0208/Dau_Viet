"use client";

import Link from "next/link";

import { withReturnTo } from "@/lib/return-to";
import { Button } from "@/components/ui/button";
import { LessonsTable } from "@/features/lessons/lessons-table";

import type { AdminEventDetail } from "@/lib/dto/event";

/** Tab Bài học — danh sách lesson thuộc event, tạo mới gán sẵn eventId. */
export function EventLessonsTab({ event }: { event: AdminEventDetail }) {
  const eventId = event.id;
  const returnTo = `/events/${eventId}?tab=lessons`;
  const newLessonHref = withReturnTo(`/lessons/new?event=${eventId}`, returnTo);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-ink-muted">
          Một sự kiện có thể có nhiều bài học — mỗi bài soạn và xuất bản độc lập.
        </p>
        <Button asChild>
          <Link href={newLessonHref}>+ Tạo bài học</Link>
        </Button>
      </div>
      <LessonsTable lockedEventId={eventId} returnTo={returnTo} />
    </div>
  );
}
