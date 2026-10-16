/** Mirrors com.dauviet.lesson.api.dto.* */

export type LessonStatus = "DRAFT" | "PUBLISHED" | "ARCHIVED";

/** AdminLessonSummaryResponse — list row. */
export interface AdminLessonSummary {
  id: string;
  eventId: string;
  title: string;
  status: LessonStatus;
  currentVersionId: string | null;
  rowVersion: number;
}

/** LessonTemplateResponse — read-only template catalogue entry. */
export interface LessonTemplate {
  id: string;
  code: string;
  name: string;
  description: string;
  schemaVersion: number;
  presetJson: string;
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
}
