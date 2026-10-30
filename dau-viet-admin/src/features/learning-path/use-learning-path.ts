"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useRef, useState } from "react";
import { ApiClientError } from "@/lib/api-error";
import type { PathAudit, PathDetail } from "@/lib/dto/learning-path";
import { DEFAULT_PATH_CODE, pathApi, pathKeys, type PathMethod } from "./path-api";

function translateServerPathError(raw: string): string {
  const t = raw.trim();
  if (t.includes("Chapter code already exists")) {
    return "Mã định danh (Code) của thời kỳ/chương này đã tồn tại trong lộ trình. Vui lòng chọn mã khác.";
  }
  if (t.includes("startYear must be less than or equal to endYear")) {
    return "Năm bắt đầu phải nhỏ hơn hoặc bằng năm kết thúc.";
  }
  if (t.includes("Move or remove all event nodes before deleting a chapter")) {
    return "Không thể xóa thời kỳ/chương đang chứa sự kiện. Hãy chuyển hoặc gỡ hết các sự kiện trước khi xóa.";
  }
  if (t.includes("Cannot delete chapter node because it still has child nodes")) {
    return "Không thể xóa đơn vị đang có các thời kỳ/giai đoạn con bên trong. Hãy xóa hoặc chuyển các nhánh con trước.";
  }
  if (t.includes("Archived events cannot be added to a path")) {
    return "Không thể gắn sự kiện đã lưu trữ (ARCHIVED) vào lộ trình.";
  }
  if (t.includes("Canonical historical event already appears in this version")) {
    return "Sự kiện lịch sử này (hoặc bản alias tương đương) đã tồn tại trong lộ trình.";
  }
  if (t.includes("Lesson is already attached to this event node")) {
    return "Bài học này đã được gắn vào sự kiện rồi.";
  }
  if (t.includes("Lesson belongs to a different event")) {
    return "Bài học không thuộc về sự kiện lịch sử này.";
  }
  if (t.includes("Only DRAFT learning paths can be changed")) {
    return "Chỉ có thể chỉnh sửa lộ trình ở trạng thái Bản nháp (DRAFT). Hãy nhân bản phiên bản hiện hành sang bản nháp để sửa.";
  }
  if (t.includes("Clone source must be the current PUBLISHED version")) {
    return "Chỉ có thể nhân bản từ phiên bản đang xuất bản (PUBLISHED).";
  }
  return t;
}

export function pathError(error: unknown, fallback = "Không thể kết nối máy chủ. Dữ liệu đã lưu vẫn được giữ nguyên."): string {
  if (error instanceof ApiClientError) {
    if (error.isConflict) {
      const reason = typeof error.details.reason === "string" ? error.details.reason : undefined;
      return reason
        ? translateServerPathError(reason)
        : "Lộ trình đã được chỉnh ở nơi khác. Tải lại dữ liệu trước khi tiếp tục.";
    }
    if (error.isForbidden) return "Bạn không có quyền quản trị lộ trình.";
    const reason = typeof error.details.reason === "string" ? error.details.reason : undefined;
    const cause = typeof error.details.cause === "string" ? error.details.cause : undefined;
    const details = Array.isArray(error.details.errors)
      ? error.details.errors
          .map((item) =>
            typeof item === "string"
              ? translateServerPathError(item)
              : typeof item === "object" && item && "message" in item
                ? translateServerPathError(String(item.message))
                : "",
          )
          .filter(Boolean)
          .join("; ")
      : "";
    const rawMsg =
      (reason ? translateServerPathError(reason) : undefined) ||
      details ||
      (error.message && error.message !== "An unexpected error occurred"
        ? translateServerPathError(error.message)
        : undefined) ||
      (cause ? translateServerPathError(cause) : undefined);
    if (rawMsg) {
      return rawMsg;
    }
    return `Lỗi máy chủ (${error.status} ${error.code}). Vui lòng kiểm tra dữ liệu và thử lại.`;
  }
  if (error instanceof Error && error.message) {
    return translateServerPathError(error.message);
  }
  return fallback;
}

export function usePathVersions(code = DEFAULT_PATH_CODE) {
  return useQuery({ queryKey: pathKeys.list(code), queryFn: () => pathApi.list(code) });
}

export function usePathVersion(versionId: string) {
  return useQuery({
    queryKey: pathKeys.detail(versionId),
    queryFn: () => pathApi.detail(versionId),
    enabled: Boolean(versionId),
    refetchOnWindowFocus: false,
  });
}

/** All writes share one synchronous gate and read the latest confirmed revision. */
export function usePathEditor(versionId: string) {
  const query = usePathVersion(versionId);
  const cache = useQueryClient();
  const inFlight = useRef(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [conflict, setConflict] = useState(false);
  const [checked, setChecked] = useState<{ report: PathAudit; revision: number } | null>(null);
  const latest = () => cache.getQueryData<PathDetail>(pathKeys.detail(versionId));
  const validation = checked && checked.revision === query.data?.version.revision ? checked.report : null;

  async function run<T>(operation: () => Promise<T>): Promise<T | null> {
    if (inFlight.current) return null;
    inFlight.current = true;
    setBusy(true);
    setError(null);
    try {
      await cache.cancelQueries({ queryKey: pathKeys.detail(versionId) });
      return await operation();
    } catch (err) {
      setError(pathError(err));
      if (err instanceof ApiClientError && err.isConflict) setConflict(true);
      return null;
    } finally {
      inFlight.current = false;
      setBusy(false);
    }
  }

  function accept(detail: PathDetail) {
    cache.setQueryData(pathKeys.detail(versionId), detail);
    setChecked(null);
    void cache.invalidateQueries({ queryKey: pathKeys.lists });
  }

  async function change(suffix: string, method: PathMethod, body?: Record<string, unknown>) {
    if (conflict) return null;
    return run(async () => {
      const current = latest();
      if (!current || current.version.status !== "DRAFT") return null;
      const detail = await pathApi.change(versionId, current.version.revision, suffix, method, body);
      accept(detail);
      return detail;
    });
  }

  async function validate() {
    if (conflict) return null;
    return run(async () => {
      setChecked(null);
      // Bind the report to a stable revision even if another editor is active.
      const before = await pathApi.detail(versionId);
      const report = await pathApi.validate(versionId);
      const after = await pathApi.detail(versionId);
      cache.setQueryData(pathKeys.detail(versionId), after);
      if (before.version.revision !== after.version.revision) {
        setError("Lộ trình đã thay đổi trong lúc kiểm tra. Vui lòng kiểm tra lại.");
        return null;
      }
      setChecked({ report, revision: after.version.revision });
      return report;
    });
  }

  async function publish() {
    if (conflict) return null;
    return run(async () => {
      const current = latest();
      if (
        !current ||
        current.version.status !== "DRAFT" ||
        !checked ||
        checked.revision !== current.version.revision ||
        checked.report.issues.some((issue) => issue.level === "ERROR")
      ) {
        setError("Kiểm tra lại lộ trình và xử lý các lỗi trước khi xuất bản.");
        return null;
      }
      const detail = await pathApi.publish(versionId, current.version.revision);
      accept(detail);
      // Archived predecessors must also be fetched again when next displayed.
      void cache.invalidateQueries({ queryKey: pathKeys.all, refetchType: "none" });
      return detail;
    });
  }

  async function reload(): Promise<void> {
    await run(async () => {
      const detail = await pathApi.detail(versionId);
      accept(detail);
      setConflict(false);
    });
  }

  return {
    query,
    detail: query.data,
    busy,
    error,
    conflict,
    validation,
    validatedRevision: validation ? checked?.revision ?? null : null,
    change,
    validate,
    publish,
    reload,
    clearError: () => setError(null),
  };
}
