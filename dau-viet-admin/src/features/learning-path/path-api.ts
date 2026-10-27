import { apiFetch, toQuery } from "@/lib/api-client";
import type { PathAudit, PathDetail, PathVersion } from "@/lib/dto/learning-path";
import { qk } from "@/lib/query-keys";

export const DEFAULT_PATH_CODE = "HISTORY_MAIN";
export const pathKeys = qk.learningPath;
const base = "/admin/learning-path/versions";
export type PathMethod = "POST" | "PATCH" | "DELETE" | "PUT";

export const pathApi = {
  list: (code = DEFAULT_PATH_CODE) => apiFetch<PathVersion[]>(`${base}${toQuery({ code })}`),
  detail: (id: string) => apiFetch<PathDetail>(`${base}/${id}`),
  create: (body: { pathCode: string; title: string; description?: string }) =>
    apiFetch<PathDetail>(base, { method: "POST", body: JSON.stringify(body) }),
  clone: (id: string) => apiFetch<PathDetail>(`${base}/${id}/clone`, { method: "POST" }),
  validate: (id: string) => apiFetch<PathAudit>(`${base}/${id}/validation`),
  publish: (id: string, expectedRevision: number) => apiFetch<PathDetail>(`${base}/${id}/publish`, {
    method: "POST", body: JSON.stringify({ expectedRevision }),
  }),
  change: (id: string, revision: number, suffix: string, method: PathMethod, body?: Record<string, unknown>) =>
    apiFetch<PathDetail>(`${base}/${id}${suffix}${method === "DELETE" ? toQuery({ expectedRevision: revision }) : ""}`, {
      method,
      ...(method === "DELETE" ? {} : { body: JSON.stringify({ ...body, expectedRevision: revision }) }),
    }),
};
