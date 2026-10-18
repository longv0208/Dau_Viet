/** Mirrors com.dauviet.lesson.api.dto.LessonVersion* */

/** LessonVersionSummary — one row of GET /admin/lessons/{id}/versions. */
export interface LessonVersionSummary {
  id: string;
  versionNo: number;
  schemaVersion: number;
  publishedAt: string;
  publishedBy: string;
}

/** LessonVersionDetail — full immutable snapshot (GET /{versionId}). */
export interface LessonVersionDetail {
  id: string;
  lessonId: string;
  versionNo: number;
  schemaVersion: number;
  publishedAt: string;
  publishedBy: string;
  snapshot: unknown;
}
