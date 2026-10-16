/** Mirrors com.dauviet.historicalevent.admin.dto.* */

export type EventStatus = "DRAFT" | "PUBLISHED" | "ARCHIVED";

/** AdminEventSummaryResponse — list row. */
export interface AdminEventSummary {
  id: string;
  slug: string;
  title: string;
  era: string;
  startYear: number | null;
  status: EventStatus;
  tags: string[];
}
