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

/** AdminEventResponse — full detail, includes status + rowVersion. */
export interface AdminEventDetail {
  id: string;
  slug: string;
  title: string;
  era: string | null;
  period: string | null;
  startYear: number | null;
  summary: string;
  description: string | null;
  location: string | null;
  coverAssetKey: string | null;
  tags: string[];
  status: EventStatus;
  rowVersion: number;
  createdAt: string;
  updatedAt: string;
}

/** AdminEventCreateRequest — POST /admin/events. */
export interface AdminEventCreateRequest {
  slug: string;
  title: string;
  era?: string;
  period?: string;
  startYear?: number;
  summary: string;
  description?: string;
  location?: string;
  coverAssetKey?: string;
  tags?: string[];
}

/** AdminEventUpdateRequest — PATCH /admin/events/{id}. Null/omitted = unchanged. */
export interface AdminEventUpdateRequest extends Partial<AdminEventCreateRequest> {
  expectedRowVersion?: number;
}
