/** Shared backend envelopes. */

/** Mirrors com.dauviet.common.api.ApiError. */
export interface ApiError {
  code: string;
  message: string;
  details: Record<string, unknown>;
  traceId: string | null;
}

/** Spring-style paged response used by admin list endpoints. */
export interface PageResponse<T> {
  content: T[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
}
