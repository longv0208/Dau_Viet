"use client";

import { StatusChip } from "@/components/status-chip";

import type { AdminEventDetail } from "@/lib/dto/event";

import { EventArchiveButton } from "../event-archive-button";
import { EventPublishButton } from "../event-publish-button";

/** Workspace header — title + status + publish/archive actions, always visible across tabs. */
export function EventWorkspaceHeader({ event }: { event: AdminEventDetail }) {
  return (
    <div className="flex flex-wrap items-center gap-3">
      <div className="min-w-0 flex-1">
        <h1 className="font-display text-2xl font-bold text-ink">{event.title}</h1>
        <p className="mt-0.5 text-sm text-ink-muted">
          {[event.era, event.startYear, event.location].filter(Boolean).join(" · ")}
        </p>
      </div>
      <StatusChip status={event.status} />
      <span className="text-xs text-ink-muted">
        Cập nhật {new Date(event.updatedAt).toLocaleString("vi-VN")}
      </span>
      <EventPublishButton event={event} />
      <EventArchiveButton event={event} />
    </div>
  );
}
