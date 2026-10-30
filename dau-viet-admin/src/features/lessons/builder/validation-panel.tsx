"use client";

import { AlertCircle } from "lucide-react";

import type { Draft } from "./draft-model";
import { STAGE_LABELS } from "./labels";
import type { FieldError } from "./use-builder";

interface Props {
  draft: Draft;
  errors: FieldError[];
  onJump: (stageId: string | null, activityId: string | null) => void;
}

const STAGE_INDEX = /stages\[(\d+)\]/;
const STAGE_BY_ID = /stages\[id=([^\]]+)\]/;
const ACT_INDEX = /activities\[(\d+)\]/;

/** Resolve a server error path to (stageId, activityId) for click-to-jump. */
export function resolveErrorPath(
  draft: Draft,
  path: string,
): { stageId: string | null; activityId: string | null } {
  let stageId: string | null = null;
  const byId = STAGE_BY_ID.exec(path);
  if (byId) {
    stageId = draft.stages.find((s) => s.id === byId[1])?.id ?? null;
  } else {
    const byIdx = STAGE_INDEX.exec(path);
    if (byIdx) stageId = draft.stages[Number(byIdx[1])]?.id ?? null;
  }
  if (!stageId) return { stageId: null, activityId: null };
  const stage = draft.stages.find((s) => s.id === stageId);
  const actIdx = ACT_INDEX.exec(path);
  const activityId =
    stage && actIdx ? (stage.activities[Number(actIdx[1])]?.id ?? null) : null;
  return { stageId, activityId };
}

/**
 * Server error codes → plain Vietnamese. Backend messages stay as fallback
 * for codes we don't know yet; codes themselves never reach the admin.
 */
export const CODE_MESSAGES: Record<string, string> = {
  MISSING_FIELD: "Thiếu thông tin bắt buộc",
  INVALID_FIELD: "Giá trị chưa hợp lệ",
  INVALID_CONFIG: "Cấu hình chưa hợp lệ",
  MISSING_CONFIG: "Chưa cấu hình hoạt động",
  UNKNOWN_FIELD: "Trường dữ liệu không được hỗ trợ",
  UNKNOWN_STAGE_ID: "Liên kết tới giai đoạn không tồn tại",
  DUPLICATE_ID: "Mã định danh bị trùng",
  INVALID_ID: "Mã định danh không hợp lệ",
  STAGE_ACTIVITY_MISMATCH: "Hoạt động không phù hợp với loại giai đoạn",
  CIRCULAR_TRANSITION: "Các giai đoạn tạo thành vòng lặp — học viên sẽ không kết thúc được",
  NO_TERMINAL_STAGE: "Không có giai đoạn kết thúc — cần một giai đoạn không dẫn tới giai đoạn nào",
  NO_REQUIRED_ACTIVITY: "Cần ít nhất một hoạt động bắt buộc (không phải chỉ đọc tư liệu)",
  REQUIRED_IN_OPTIONAL_STAGE: "Hoạt động bắt buộc nằm trong giai đoạn tuỳ chọn — hãy bỏ bắt buộc hoặc đánh dấu giai đoạn là bắt buộc",
  EVIDENCE_NOT_FOUND: "Bằng chứng đã chọn không còn tồn tại hoặc không khả dụng cho sự kiện này",
  ASSET_NOT_FOUND: "Tư liệu (ảnh, file) đã chọn không còn tồn tại",
  MISSING_DRAFT: "Bản nháp trống",
  INVALID_DRAFT: "Cấu trúc bản nháp không hợp lệ",
  UNSUPPORTED_SCHEMA_VERSION: "Phiên bản cấu trúc không được hỗ trợ",
  EMPTY_COMPLETION: "Phần điều kiện hoàn thành để trống — hãy chọn điều kiện hoặc bỏ phần này",
  UNSUPPORTED_ACTIVITY_TYPE: "Loại hoạt động không được hỗ trợ",
  EVENT_NOT_PUBLISHED: "Sự kiện cha chưa được xuất bản — hãy xuất bản sự kiện trước khi xuất bản bài học",
};

/**
 * Trích xuất stage-id/activity-index trực tiếp từ path (không cần draft) —
 * fallback khi draft null hoặc stage id không còn trong draft nữa.
 */
function describePathLoose(path: string): string | null {
  const sid = STAGE_BY_ID.exec(path)?.[1];
  const sidx = STAGE_INDEX.exec(path)?.[1];
  const aidx = ACT_INDEX.exec(path)?.[1];
  if (!sid && !sidx) {
    if (path.startsWith("completion")) return "Điều kiện hoàn thành";
    if (path.startsWith("objectives")) return "Mục tiêu học tập";
    if (path === "schemaVersion") return "Định dạng bản nháp";
    if (path === "centralQuestion") return "Câu hỏi trung tâm";
    if (path === "templateId") return "Mẫu bài học";
    if (path === "eventId") return "Sự kiện cha";
    return null;
  }
  const stagePart = sid ? `Giai đoạn «${sid}»` : `Giai đoạn ${Number(sidx) + 1}`;
  if (aidx == null) return stagePart;
  return `${stagePart} · Hoạt động ${Number(aidx) + 1}`;
}

/** Path → human location: «Giai đoạn 2 · Hoạt động 1» / «Giai đoạn Bối cảnh». */
export function describePath(draft: Draft | null | undefined, path: string): string | null {
  if (!draft) return describePathLoose(path);
  const { stageId, activityId } = resolveErrorPath(draft, path);
  const stageIdx = stageId ? draft.stages.findIndex((s) => s.id === stageId) : -1;
  const stage = stageIdx >= 0 ? draft.stages[stageIdx] : null;
  if (!stage) return describePathLoose(path);
  const stageName = stage.title || STAGE_LABELS[stage.type]?.label || `Giai đoạn ${stageIdx + 1}`;
  const activity = activityId ? stage.activities.find((a) => a.id === activityId) : null;
  if (!activity) return `Giai đoạn «${stageName}»`;
  const actIdx = stage.activities.findIndex((a) => a.id === activity.id);
  const actName = activity.instruction?.trim().slice(0, 40) || `Hoạt động ${actIdx + 1}`;
  return `Giai đoạn «${stageName}» · ${actName}`;
}

/** Right-pane list of server-side DRAFT_SCHEMA_INVALID errors. */
export function ValidationPanel({ draft, errors, onJump }: Props) {
  if (errors.length === 0) return null;
  return (
    <section
      aria-label="Lỗi lưu bản nháp"
      className="flex flex-col gap-2 rounded-md border border-error/40 bg-error/5 p-3"
    >
      <h4 className="flex items-center gap-1.5 text-sm font-semibold text-error">
        <AlertCircle className="size-4" aria-hidden /> Cần sửa ({errors.length})
      </h4>
      <ul className="flex flex-col gap-1">
        {errors.map((e, i) => {
          const target = resolveErrorPath(draft, e.path);
          const where = describePath(draft, e.path);
          const detail = (e as { detail?: string }).detail;
          const clickable = target.stageId != null;
          return (
            <li key={`${e.path}-${i}`}>
              <button
                type="button"
                disabled={!clickable}
                onClick={() => onJump(target.stageId, target.activityId)}
                className="w-full rounded px-2 py-1 text-left text-xs text-ink hover:bg-error/10"
              >
                {where && (
                  <span className="block text-[10px] font-medium text-ink-muted">{where}</span>
                )}
                <span className="text-error">
                  {detail ?? CODE_MESSAGES[e.code] ?? "Cần xem lại nội dung đã nhập"}
                </span>
              </button>
            </li>
          );
        })}
      </ul>
      <p className="text-[11px] text-ink-muted">
        Bấm vào lỗi để chuyển tới giai đoạn/hoạt động tương ứng.
      </p>
    </section>
  );
}
