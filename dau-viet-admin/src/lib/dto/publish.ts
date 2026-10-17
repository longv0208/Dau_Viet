/** Mirrors publish/preview DTOs of AdminLessonController + learner content. */

export interface PublishIssue {
  path?: string;
  code?: string;
  message: string;
}

/**
 * PublishReadinessResponse — POST /admin/lessons/{id}/validate.
 * `summary` is a Map<String,Object> backend-side (stageCount, activityCount,
 * evidenceRefs, schemaVersion, errorCount, warningCount) — NOT a string.
 */
export interface PublishReadiness {
  ready: boolean;
  errors: PublishIssue[];
  warnings: PublishIssue[];
  summary?: Record<string, unknown>;
}

/** PublishResponse — POST /admin/lessons/{id}/publish. */
export interface PublishResponse {
  lessonId: string;
  lessonVersionId: string;
  versionNo: number;
  status: string;
  publishedAt: string;
}

/**
 * LearnerLessonContent — POST /admin/lessons/{id}/preview (admin draft
 * projection; versionNo/lessonVersionId null) and GET /api/v1/lessons/{id}/content
 * (published snapshot; versionNo/lessonVersionId real).
 */
export interface LearnerLessonContent {
  lessonId: string;
  lessonVersionId: string | null;
  versionNo: number | null;
  content: unknown;
}
