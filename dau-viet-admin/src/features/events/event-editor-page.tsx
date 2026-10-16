"use client";

import { useQuery } from "@tanstack/react-query";

import { apiFetch } from "@/lib/api-client";
import type { AdminEventDetail } from "@/lib/dto/event";
import { qk } from "@/lib/query-keys";
import { ErrorState } from "@/components/error-state";
import { Skeleton } from "@/components/ui/skeleton";
import { StatusChip } from "@/components/status-chip";

import { EventForm } from "./event-form";

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
      <div className="flex items-center gap-3">
        <StatusChip status={ev.status} />
        <span className="text-xs text-ink-muted">
          Cập nhật {new Date(ev.updatedAt).toLocaleString("vi-VN")}
        </span>
      </div>
      <EventForm initial={ev} />
    </div>
  );
}
