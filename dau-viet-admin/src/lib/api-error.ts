import type { ApiError } from "./dto/common";

/**
 * Typed error thrown by apiFetch. Preserves the backend ApiError envelope —
 * `code` is the stable machine key (INVALID_CREDENTIALS, FORBIDDEN, ...),
 * `traceId` aids support correlation.
 */
export class ApiClientError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details: Record<string, unknown>;
  readonly traceId: string | null;

  constructor(status: number, body: Partial<ApiError> | null) {
    super(body?.message ?? "Yêu cầu thất bại");
    this.name = "ApiClientError";
    this.status = status;
    this.code = body?.code ?? `HTTP_${status}`;
    this.details = body?.details ?? {};
    this.traceId = body?.traceId ?? null;
  }

  static from(body: unknown, status: number): ApiClientError {
    if (body && typeof body === "object" && ("code" in body || "message" in body)) {
      return new ApiClientError(status, body as Partial<ApiError>);
    }
    return new ApiClientError(status, null);
  }

  get isUnauthorized() {
    return this.status === 401;
  }
  get isForbidden() {
    return this.status === 403;
  }
  get isNotFound() {
    return this.status === 404;
  }
  get isConflict() {
    return this.status === 409;
  }
  get isValidation() {
    return this.status === 400 || this.status === 422;
  }
}

/** Map an ApiClientError to a Vietnamese admin-facing message. */
export function toUserMessage(err: unknown): string {
  if (err instanceof ApiClientError) {
    switch (err.code) {
      case "INVALID_CREDENTIALS":
        return "Email hoặc mật khẩu không đúng";
      case "UNAUTHORIZED":
        return "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại";
      case "FORBIDDEN":
        return "Bạn không có quyền thực hiện thao tác này";
      case "UPSTREAM_UNAVAILABLE":
        return "Không thể kết nối máy chủ backend";
      case "EVENT_NOT_PUBLISHED":
        return "Sự kiện lịch sử chưa được xuất bản — bài học chỉ xuất bản khi sự kiện đã ở trạng thái ĐÃ XUẤT BẢN";
      case "EVENT_IN_USE":
        return "Sự kiện đang được bài học tham chiếu — không thể lưu trữ";
      case "INVALID_STATUS_TRANSITION":
        return "Trạng thái hiện tại không cho phép thao tác này";
      case "OPTIMISTIC_LOCK_CONFLICT":
        return "Dữ liệu đã bị sửa đồng thời — tải lại để lấy bản mới nhất";
      case "DRAFT_SCHEMA_INVALID":
        return "Bản nháp chưa hợp lệ — xem danh sách lỗi chi tiết";
      case "LESSON_NOT_PUBLISHED":
        return "Bài học chưa được xuất bản";
      default:
        return err.message || "Có lỗi xảy ra, vui lòng thử lại";
    }
  }
  return "Không thể kết nối máy chủ, vui lòng thử lại";
}
