"use client";

import { AlertTriangle, CheckCircle2, Info } from "lucide-react";
import Link from "next/link";
import type { PathAudit, PathAuditIssue, PathDetail } from "@/lib/dto/learning-path";
import { cn } from "@/lib/utils";

const ISSUE_CODE_TITLES: Record<string, string> = {
  EMPTY_PATH: "Lộ trình chưa có chương/thời kỳ",
  INVALID_HIERARCHY: "Cấu trúc phân cấp chương không hợp lệ",
  NO_REQUIRED_EVENT: "Chưa có sự kiện bắt buộc trong lộ trình",
  DUPLICATE_CHAPTER_CODE: "Trùng mã định danh (Code) thời kỳ/chương",
  INVALID_CHAPTER_YEARS: "Khoảng năm của thời kỳ/chương không hợp lệ",
  CHAPTER_CHRONOLOGY: "Thứ tự niên đại giữa các thời kỳ chưa tăng dần",
  EMPTY_CHAPTER: "Thời kỳ / Giai đoạn chưa có sự kiện",
  DUPLICATE_EVENT_IN_PATH: "Sự kiện bị gắn trùng lặp trong lộ trình",
  CANONICAL_ALIAS: "Sự kiện là bản định danh thay thế (Alias)",
  DUPLICATE_HISTORICAL_ALIAS: "Trùng lặp sự kiện lịch sử gốc",
  UNPUBLISHED_EVENT_IN_PATH: "Sự kiện chưa được xuất bản",
  INVALID_EVENT_YEAR: "Năm diễn ra sự kiện không hợp lệ",
  EVENT_CHRONOLOGY: "Thứ tự niên đại sự kiện trong thời kỳ chưa tăng dần",
  EVENT_OUTSIDE_CHAPTER: "Năm sự kiện nằm ngoài khoảng năm của thời kỳ",
  DUPLICATE_LESSON_IN_PATH: "Bài học bị gắn trùng lặp",
  LESSON_EVENT_MISMATCH: "Bài học không thuộc về sự kiện tương ứng",
  UNPUBLISHED_OR_UNPINNED_LESSON: "Bài học chưa được xuất bản",
  NO_PUBLISHED_LESSON: "Sự kiện chưa có bài học đã xuất bản trong lộ trình",
  NO_COMPLETION_POLICY: "Sự kiện thiếu Chính sách hoàn thành (Completion Policy)",
  CONTENT_REVIEW_REQUIRED: "Nội dung sự kiện/bài học cần hoàn thiện & xuất bản",
  INVALID_EVENT_SCOPE: "Phạm vi sự kiện trong lộ trình không hợp lệ",
  INVALID_CHAPTER_SORT: "Thứ tự sắp xếp chương không hợp lệ",
  INVALID_EVENT_SORT: "Thứ tự sắp xếp sự kiện không hợp lệ",
  INVALID_LESSON_SORT: "Thứ tự sắp xếp bài học không hợp lệ",
};

const ISSUE_FIX_HINTS: Record<string, string> = {
  EMPTY_CHAPTER:
    "Cách xử lý: Chọn thời kỳ này ở cột trái → tìm và bấm «Gắn vào chương» ở danh mục sự kiện phía dưới (hoặc xóa thời kỳ nếu không sử dụng).",
  CHAPTER_CHRONOLOGY:
    "Cách xử lý: Kéo thả sắp xếp lại thứ tự thời kỳ ở cột bên trái theo trình tự thời gian từ cổ đại đến hiện đại, hoặc chỉnh lại Năm bắt đầu.",
  INVALID_CHAPTER_YEARS:
    "Cách xử lý: Bấm biểu tượng cây bút trên thời kỳ để sửa lại Năm bắt đầu nhỏ hơn hoặc bằng Năm kết thúc.",
  EVENT_OUTSIDE_CHAPTER:
    "Cách xử lý: Mở rộng khoảng năm (Năm bắt đầu – Năm kết thúc) của Thời kỳ chứa sự kiện này, hoặc chuyển sự kiện sang đúng Thời kỳ tương ứng.",
  EVENT_CHRONOLOGY:
    "Cách xử lý: Kéo thả sắp xếp lại thứ tự các sự kiện trong thời kỳ theo đúng trình tự năm lịch sử.",
  NO_PUBLISHED_LESSON:
    "Cách xử lý: Bấm vào sự kiện trong lộ trình → ở mục «Thêm bài từ sự kiện này», bấm «Gắn vào sự kiện» cho ít nhất 1 bài học đã xuất bản.",
  NO_COMPLETION_POLICY:
    "Cách xử lý: Mở trang quản lý Sự kiện → chuyển sang tab «Gamification & Mở khóa» → Lưu và Xuất bản Chính sách hoàn thành (Completion Policy), đồng thời đảm bảo mọi bài học bắt buộc trong policy đều đã được gắn vào sự kiện trên lộ trình.",
  CONTENT_REVIEW_REQUIRED:
    "Cách xử lý: Kiểm tra và Xuất bản (Publish) cả Sự kiện lẫn các Bài học đã gắn vào sự kiện này.",
  UNPUBLISHED_EVENT_IN_PATH:
    "Cách xử lý: Mở trang Sự kiện và bấm nút «Xuất bản» sự kiện trước khi xuất bản lộ trình.",
  UNPUBLISHED_OR_UNPINNED_LESSON:
    "Cách xử lý: Mở bài học đang ở trạng thái Bản nháp → Kiểm tra & Xuất bản bài học.",
};

function translateLegacyMessage(
  issue: PathAuditIssue,
  chapterTitle?: string | null,
  eventTitle?: string | null,
): string {
  const msg = issue.message.trim();
  const ch = chapterTitle ? `«${chapterTitle}»` : "này";
  const ev = eventTitle ? `«${eventTitle}»` : "này";

  if (msg === "Chapter has no events") {
    return `Thời kỳ / Giai đoạn ${ch} hiện chưa có sự kiện lịch sử nào được gắn vào.`;
  }
  if (msg === "Chapter dates go backwards in admin order") {
    return `Niên đại của thời kỳ ${ch} đang nhỏ hơn thời kỳ đứng trước theo thứ tự sắp xếp.`;
  }
  if (msg === "Event year is outside chapter dates") {
    return `Năm diễn ra sự kiện ${ev} nằm ngoài khoảng năm của thời kỳ ${ch}.`;
  }
  if (msg === "Event dates go backwards in admin order") {
    return `Thứ tự năm của sự kiện ${ev} đang nhỏ hơn sự kiện đứng trước trong thời kỳ ${ch}.`;
  }
  if (msg === "Attached lesson has no published version") {
    return `Một bài học được gắn trong sự kiện ${ev} chưa được xuất bản (chưa có phiên bản PUBLISHED).`;
  }
  if (msg === "Event is missing, archived or unpublished") {
    return `Sự kiện ${ev} chưa được xuất bản (đang ở trạng thái Bản nháp hoặc đã Lưu trữ).`;
  }
  if (msg.startsWith("Event is not ready for required participation:")) {
    if (issue.code === "NO_PUBLISHED_LESSON") {
      return `Sự kiện ${ev} chưa có bài học đã xuất bản nào được gắn vào lộ trình.`;
    }
    if (issue.code === "NO_COMPLETION_POLICY") {
      return `Sự kiện ${ev} chưa có Chính sách hoàn thành (Completion Policy) đã xuất bản, hoặc chưa gắn đủ bài học bắt buộc theo chính sách.`;
    }
    return `Sự kiện ${ev} chưa đủ điều kiện sẵn sàng học tập (cần xuất bản sự kiện, bài học và chính sách hoàn thành).`;
  }
  return msg;
}

export function PathValidation({
  report,
  detail,
  onSelect,
  onSelectTarget,
}: {
  report: PathAudit;
  detail: PathDetail;
  onSelect: (chapterId: string, eventNodeId?: string) => void;
  onSelectTarget?: (targetId: string) => void;
}) {
  const errors = report.issues.filter((issue) => issue.level === "ERROR");
  const warnings = report.issues.filter((issue) => issue.level === "WARNING");
  return (
    <section aria-label="Kết quả kiểm tra lộ trình" className="space-y-3">
      <p
        role="status"
        className={cn(
          "flex items-center gap-2 text-sm font-medium",
          errors.length ? "text-error" : "text-ink",
        )}
      >
        {errors.length ? (
          <AlertTriangle className="size-4" aria-hidden />
        ) : (
          <CheckCircle2 className="size-4" aria-hidden />
        )}
        {errors.length} lỗi chặn xuất bản · {warnings.length} cảnh báo
      </p>
      {report.issues.length === 0 && (
        <p className="text-sm text-ink-muted">
          Lộ trình đáp ứng điều kiện xuất bản.
        </p>
      )}
      <ul className="space-y-2">
        {report.issues.map((issue, index) => {
          const targetId = issue.targetId?.trim() || null;
          const chapter = targetId
            ? detail.chapters.find(
                (row) =>
                  row.chapter.id === targetId ||
                  row.events.some(
                    (event) =>
                      event.node.id === targetId ||
                      event.node.eventId === targetId ||
                      event.canonicalEventId === targetId ||
                      event.lessons.some(
                        (lesson) =>
                          lesson.node.id === targetId ||
                          lesson.node.lessonId === targetId,
                      ),
                  ),
              )
            : undefined;
          const event = chapter?.events.find(
            (row) =>
              row.node.id === targetId ||
              row.node.eventId === targetId ||
              row.canonicalEventId === targetId ||
              row.lessons.some(
                (lesson) =>
                  lesson.node.id === targetId ||
                  lesson.node.lessonId === targetId,
              ),
          );
          const Icon = issue.level === "ERROR" ? AlertTriangle : Info;
          const levelBadge =
            issue.level === "ERROR"
              ? "Lỗi chặn xuất bản"
              : issue.level === "WARNING"
                ? "Cảnh báo (vẫn có thể xuất bản)"
                : "Thông tin";
          const title = ISSUE_CODE_TITLES[issue.code] ?? levelBadge;
          const displayMessage = translateLegacyMessage(
            issue,
            chapter?.chapter.title,
            event?.title,
          );
          const hint = ISSUE_FIX_HINTS[issue.code];

          return (
            <li
              key={`${issue.code}-${issue.targetId}-${index}`}
              className={cn(
                "rounded-lg border p-3.5 text-sm",
                issue.level === "ERROR"
                  ? "border-error/40 bg-error/5"
                  : "border-warning/50 bg-warning/5",
              )}
            >
              <div className="flex items-start gap-2.5">
                <Icon
                  className={cn(
                    "mt-0.5 size-4 shrink-0",
                    issue.level === "ERROR" ? "text-error" : "text-warning",
                  )}
                  aria-hidden
                />
                <div className="min-w-0 flex-1 space-y-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span
                      className={cn(
                        "rounded px-1.5 py-0.5 text-[11px] font-bold uppercase tracking-wide",
                        issue.level === "ERROR"
                          ? "bg-error/15 text-error"
                          : "bg-warning/20 text-ink",
                      )}
                    >
                      {issue.level === "ERROR" ? "Lỗi" : "Cảnh báo"}
                    </span>
                    <span className="font-semibold text-ink">{title}</span>
                  </div>

                  {(chapter || event) && (
                    <p className="text-xs font-medium text-ink-secondary">
                      Vị trí:{" "}
                      {chapter ? `Thời kỳ «${chapter.chapter.title}»` : ""}
                      {event ? ` → Sự kiện «${event.title ?? event.node.eventId}»` : ""}
                    </p>
                  )}

                  <p className="break-words text-sm text-ink">{displayMessage}</p>

                  {hint && (
                    <p className="rounded bg-white/75 px-2.5 py-1.5 text-xs text-ink-muted">
                      {hint}
                    </p>
                  )}

                  <div className="flex flex-wrap items-center gap-3 pt-1">
                    {onSelectTarget && targetId && chapter ? (
                      <button
                        type="button"
                        title={event?.title ?? chapter?.chapter.title ?? undefined}
                        className="text-xs font-semibold text-brand underline cursor-pointer"
                        onClick={() => onSelectTarget(targetId)}
                      >
                        Đi tới mục này →
                      </button>
                    ) : chapter ? (
                      <button
                        type="button"
                        className="text-xs font-semibold text-brand underline cursor-pointer"
                        onClick={() =>
                          onSelect(chapter.chapter.id, event?.node.id)
                        }
                      >
                        Đi tới {event?.title ?? chapter.chapter.title}
                      </button>
                    ) : null}

                    {event && (
                      <Link
                        href={`/events/${event.node.eventId}?tab=gamification`}
                        className="text-xs font-medium text-ink-secondary underline hover:text-brand"
                      >
                        Mở trang cấu hình Sự kiện ↗
                      </Link>
                    )}
                  </div>
                </div>
              </div>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
