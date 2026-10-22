/** Mirrors com.dauviet.map.admin.dto.* */

export type MapLocationStatus = "DRAFT" | "PUBLISHED" | "ARCHIVED";

/** AdminMapLocationResponse — full row including optimistic-lock version. */
export interface AdminMapLocation {
  id: string;
  eventId: string;
  title: string;
  description: string | null;
  latitude: number;
  longitude: number;
  unlockLessonId: string | null;
  unlockLessonTitle: string | null;
  displayOrder: number;
  status: MapLocationStatus;
  rowVersion: number;
  createdAt: string;
  updatedAt: string;
}

/** AdminMapLocationRequest — POST/PATCH under /admin/events/{eventId}/map-locations. */
export interface AdminMapLocationRequest {
  title: string;
  description?: string;
  latitude: number;
  longitude: number;
  /** null/absent = always AVAILABLE to learners. */
  unlockLessonId?: string | null;
  displayOrder?: number;
}
