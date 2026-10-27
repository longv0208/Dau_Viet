import type { PathDetail } from "@/lib/dto/learning-path";

export type PathChange = (
  suffix: string,
  method: "POST" | "PATCH" | "DELETE" | "PUT",
  body?: Record<string, unknown>,
) => Promise<PathDetail | null>;

export function historicalYear(year: number | null | undefined): string {
  if (year == null) return "Chưa rõ năm";
  return year < 0 ? `${Math.abs(year)} TCN` : `${year}`;
}

export const CONTENT_LABELS: Record<string, string> = {
  PLAYABLE: "Sẵn sàng học",
  NO_PUBLISHED_LESSON: "Chưa có bài đã xuất bản",
  NO_COMPLETION_POLICY: "Chưa có chính sách hoàn thành",
  CONTENT_REVIEW_REQUIRED: "Cần kiểm tra nội dung",
};
