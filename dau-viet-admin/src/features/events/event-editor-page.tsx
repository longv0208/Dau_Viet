"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";

import { apiFetch } from "@/lib/api-client";
import type { AdminEventDetail } from "@/lib/dto/event";
import { qk } from "@/lib/query-keys";
import { ErrorState } from "@/components/error-state";
import { Skeleton } from "@/components/ui/skeleton";
import { StatusChip } from "@/components/status-chip";
import { Button } from "@/components/ui/button";

import { EventForm } from "./event-form";
import { EventArchiveButton } from "./event-archive-button";
import { EventPublishButton } from "./event-publish-button";
import { MapLocationsSection } from "./map-locations-section";

/** Loads GET /admin/events/{id} and renders the edit form. */
export function EventEditorPage({ eventId }: { eventId: string }) {
  const query = useQuery({
    queryKey: qk.events.detail(eventId),
    queryFn: () => apiFetch<AdminEventDetail>(`/admin/events/${eventId}`),
  });

  if (query.isPending) {
    return (
      <div className="flex flex-col gap-4">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-64 w-full" />
      </div>
    );
  }
  if (query.isError) return <ErrorState error={query.error} onRetry={() => query.refetch()} />;

  const ev = query.data;
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3">
        <StatusChip status={ev.status} />
        <span className="text-xs text-ink-muted">
          Cập nhật {new Date(ev.updatedAt).toLocaleString("vi-VN")}
        </span>
        <EventPublishButton event={ev} />
        <EventArchiveButton event={ev} />
        <Button asChild variant="secondary" className="ml-auto">
          <Link href={`/lessons/new?event=${ev.id}`}>+ Tạo bài học cho sự kiện này</Link>
        </Button>
      </div>
      <EventForm initial={ev} />
      <hr className="border-border" />
      <MapLocationsSection eventId={ev.id} />
    </div>
  );
}
