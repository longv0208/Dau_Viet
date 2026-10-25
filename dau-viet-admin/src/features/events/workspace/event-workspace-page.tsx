"use client";

import { useQuery } from "@tanstack/react-query";

import { apiFetch } from "@/lib/api-client";
import type { AdminEventDetail } from "@/lib/dto/event";
import { qk } from "@/lib/query-keys";
import { ErrorState } from "@/components/error-state";
import { Skeleton } from "@/components/ui/skeleton";

import { EventWorkspaceHeader } from "./event-workspace-header";
import { EventWorkspaceTabs } from "./event-workspace-tabs";
import { EventOverviewTab } from "./event-overview-tab";
import { EventLessonsTab } from "./event-lessons-tab";
import { EventHocLieuTab } from "./event-hoc-lieu-tab";
import { EventGamificationTab } from "./event-gamification-tab";
import { EventInfoTab } from "./event-info-tab";
import type { EventWorkspaceTab } from "./types";

/** Root client component — fetch event once, render header + tabs + active tab. */
export function EventWorkspacePage({
  eventId,
  tab,
}: {
  eventId: string;
  tab: EventWorkspaceTab;
}) {
  const query = useQuery({
    queryKey: qk.events.detail(eventId),
    queryFn: () => apiFetch<AdminEventDetail>(`/admin/events/${eventId}`),
  });

  if (query.isPending) {
    return (
      <div className="flex flex-col gap-4">
        <Skeleton className="h-10 w-80" />
        <Skeleton className="h-8 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    );
  }
  if (query.isError) {
    return <ErrorState error={query.error} onRetry={() => query.refetch()} />;
  }

  const event = query.data;
  return (
    <div className="flex flex-col gap-6">
      <EventWorkspaceHeader event={event} />
      <EventWorkspaceTabs eventId={eventId} active={tab} />
      {tab === "overview" && <EventOverviewTab event={event} />}
      {tab === "lessons" && <EventLessonsTab event={event} />}
      {tab === "hoc-lieu" && <EventHocLieuTab event={event} />}
      {tab === "gamification" && <EventGamificationTab event={event} />}
      {tab === "info" && <EventInfoTab event={event} />}
    </div>
  );
}
