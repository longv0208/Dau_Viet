/** Mirrors PublishReadinessResponse — POST /admin/lessons/{id}/validate. */

export interface PublishIssue {
  path?: string;
  code?: string;
  message: string;
}

export interface PublishReadiness {
  ready: boolean;
  errors: PublishIssue[];
  warnings: PublishIssue[];
  summary?: string;
}
