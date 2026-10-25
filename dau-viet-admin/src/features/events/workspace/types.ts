/** Tab slugs for /events/[id]?tab=<slug> — whitelisted, anything else falls back to overview. */
export type EventWorkspaceTab =
  | "overview"
  | "lessons"
  | "hoc-lieu"
  | "gamification"
  | "info";

export const EVENT_WORKSPACE_TABS: readonly {
  slug: EventWorkspaceTab;
  label: string;
}[] = [
  { slug: "overview", label: "Tổng quan" },
  { slug: "lessons", label: "Bài học" },
  { slug: "hoc-lieu", label: "Học liệu" },
  { slug: "gamification", label: "Gamification" },
  { slug: "info", label: "Thông tin & địa điểm" },
];

/** Normalise a raw `?tab=` value to a known slug (default `overview`). */
export function parseEventTab(raw: string | null | undefined): EventWorkspaceTab {
  if (raw === "lessons" || raw === "hoc-lieu" || raw === "gamification" || raw === "info")
    return raw;
  return "overview";
}
