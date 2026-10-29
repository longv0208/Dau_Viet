"use client";

import Link from "next/link";

import { cn } from "@/lib/utils";

import { EVENT_WORKSPACE_TABS, type EventWorkspaceTab } from "./types";

/** Horizontal tab nav for the event workspace — each tab is a ?tab= deep link. */
export function EventWorkspaceTabs({
  eventId,
  active,
}: {
  eventId: string;
  active: EventWorkspaceTab;
}) {
  return (
    <nav aria-label="Không gian sự kiện" className="flex flex-wrap gap-1 border-b-2 border-heading">
      {EVENT_WORKSPACE_TABS.map((t) => {
        const href = `/events/${eventId}?tab=${t.slug}`;
        const isActive = t.slug === active;
        return (
          <Link
            key={t.slug}
            href={href}
            aria-current={isActive ? "page" : undefined}
            className={cn(
              "rounded-t-md border-b-2 px-4 py-2 text-sm font-medium transition-colors",
              isActive
                ? "border-brand bg-brand/10 text-brand"
                : "border-transparent text-ink-muted hover:bg-surface-alt hover:text-ink",
            )}
          >
            {t.label}
          </Link>
        );
      })}
    </nav>
  );
}
