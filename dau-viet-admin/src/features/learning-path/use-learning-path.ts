"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useRef, useState } from "react";
import { ApiClientError } from "@/lib/api-error";
import type { PathAudit, PathDetail } from "@/lib/dto/learning-path";
import { DEFAULT_PATH_CODE, pathApi, pathKeys, type PathMethod } from "./path-api";

export function pathError(error: unknown): string {
  if (error instanceof ApiClientError) {
    if (error.isConflict) return "Lộ trình đã được chỉnh ở nơi khác. Tải lại dữ liệu trước khi tiếp tục.";
    if (error.isForbidden) return "Bạn không có quyền quản trị lộ trình.";
    const details = Array.isArray(error.details.errors) ? error.details.errors.filter(v => typeof v === "string").join("; ") : "";
    return details || error.message;
  }
  return "Không thể kết nối máy chủ. Dữ liệu đã lưu vẫn được giữ nguyên.";
}

export function usePathVersions(code = DEFAULT_PATH_CODE) {
  return useQuery({ queryKey: pathKeys.list(code), queryFn: () => pathApi.list(code) });
}

export function usePathVersion(versionId: string) {
  return useQuery({
    queryKey: pathKeys.detail(versionId), queryFn: () => pathApi.detail(versionId),
    enabled: Boolean(versionId), refetchOnWindowFocus: false,
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
      if (!current || current.version.status !== "DRAFT" || !checked
          || checked.revision !== current.version.revision
          || checked.report.issues.some(issue => issue.level === "ERROR")) {
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

  return { query, detail: query.data, busy, error, conflict, validation,
    validatedRevision: validation ? checked?.revision ?? null : null,
    change, validate, publish, reload, clearError: () => setError(null) };
}
