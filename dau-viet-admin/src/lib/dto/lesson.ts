import type { HeritageBackgroundConfig } from "./heritage-background";

/** Mirrors com.dauviet.lesson.api.dto.* */

export type LessonStatus = "DRAFT" | "PUBLISHED" | "ARCHIVED";

/** AdminLessonSummaryResponse — list row. */
export interface AdminLessonSummary {
  id: string;
  eventId: string;
  title: string;
  status: LessonStatus;
  currentVersionId: string | null;
  coverAssetId?: string | null;
  rowVersion: number;
}

/** AdminLessonResponse — full detail with draft + audit fields. */
export interface AdminLessonDetail {
  id: string;
  eventId: string;
  templateId: string;
  title: string;
  centralQuestion: string;
  objectivesJson: string;
  draftJson: string;
  status: LessonStatus;
  currentVersionId: string | null;
  coverAssetId?: string | null;
  backgroundConfig?: HeritageBackgroundConfig | null;
  rowVersion: number;
  createdBy: string;
  updatedBy: string;
  createdAt: string;
  updatedAt: string;
}

/** AdminLessonCreateRequest — POST /admin/lessons. */
export interface AdminLessonCreateRequest {
  eventId: string;
  templateId: string;
  title: string;
  centralQuestion: string;
  objectivesJson?: string;
  draftJson?: string;
  coverAssetId?: string | null;
  backgroundConfig?: HeritageBackgroundConfig | null;
}

/** AdminLessonUpdateRequest — PATCH /admin/lessons/{id}. */
export interface AdminLessonUpdateRequest {
  templateId?: string;
  title?: string;
  centralQuestion?: string;
  objectivesJson?: string;
  expectedRowVersion?: number;
  coverAssetId?: string | null;
  clearCoverAsset?: boolean;
  backgroundConfig?: HeritageBackgroundConfig | null;
  clearBackgroundConfig?: boolean;
}

/** LessonTemplateResponse — template catalogue entry (GET returns List, not paged). */
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

/** AdminLessonTemplateCreateRequest — POST /admin/lesson-templates. */
export interface AdminLessonTemplateCreateRequest {
  code: string;
  name: string;
  description?: string;
  presetJson: string;
}

/** AdminLessonTemplateUpdateRequest — PATCH /admin/lesson-templates/{id}. `code` is immutable. */
export interface AdminLessonTemplateUpdateRequest {
  name?: string;
  description?: string;
  presetJson?: string;
  enabled?: boolean;
}
