import { ApiClientError } from "@/lib/api-error";
import { apiFetch, toQuery } from "@/lib/api-client";
import { authStore } from "@/features/auth/auth-store";
import { coordinatedRefresh } from "@/features/auth/refresh-coordinator";
import type { PageResponse } from "@/lib/dto/common";

import type {
  AnimationSceneDetail,
  AnimationSceneSummary,
  AnimationTemplateDto,
  SceneValidationResult,
  SceneVersionDetail,
  SceneVersionSummary,
} from "./animation-types";

const TPL = "/admin/animation-templates";
const SCN = "/admin/animation-scenes";

export interface SceneListParams {
  page?: number;
  size?: number;
  status?: string;
  q?: string;
  templateId?: string;
  sort?: string;
}

export const animationApi = {
  /* ---------- Templates ---------- */
  listTemplates: (params?: { page?: number; size?: number; rendererCode?: string; enabled?: boolean; q?: string }) =>
    apiFetch<PageResponse<AnimationTemplateDto>>(
      `${TPL}${toQuery({
        size: 100,
        page: params?.page,
        rendererCode: params?.rendererCode,
        enabled: params?.enabled == null ? undefined : params.enabled ? "true" : "false",
        q: params?.q,
      })}`,
    ),

  /* ---------- Scenes ---------- */
  listScenes: (params?: SceneListParams) =>
    apiFetch<PageResponse<AnimationSceneSummary>>(`${SCN}${toQuery({ size: 20, ...params })}`),
  getScene: (id: string) => apiFetch<AnimationSceneDetail>(`${SCN}/${id}`),
  createScene: (data: { templateId: string; title: string; eventId?: string; draftJson?: string }) =>
    apiFetch<AnimationSceneDetail>(SCN, { method: "POST", body: JSON.stringify(data) }),
  /** PATCH mang title/eventId/clearEvent/draftJson/expectedRowVersion trong một payload. */
  updateScene: (
    id: string,
    data: {
      title?: string;
      eventId?: string;
      clearEvent?: boolean;
      draftJson?: string;
      expectedRowVersion?: number;
    },
  ) => apiFetch<AnimationSceneDetail>(`${SCN}/${id}`, { method: "PATCH", body: JSON.stringify(data) }),
  duplicateScene: (id: string) =>
    apiFetch<AnimationSceneDetail>(`${SCN}/${id}/duplicate`, { method: "POST" }),
  validateScene: (id: string) =>
    apiFetch<SceneValidationResult>(`${SCN}/${id}/validate`, { method: "POST" }),
  publishScene: (id: string, expectedRowVersion: number) =>
    apiFetch<{ sceneId: string; versionId: string; versionNo: number }>(
      `${SCN}/${id}/publish`,
      { method: "POST", body: JSON.stringify({ expectedRowVersion }) },
    ),
  archiveScene: (id: string) =>
    apiFetch<AnimationSceneDetail>(`${SCN}/${id}/archive`, { method: "POST" }),

  /* ---------- Versions ---------- */
  listVersions: (id: string) => apiFetch<SceneVersionSummary[]>(`${SCN}/${id}/versions`),
  getVersion: (id: string, versionId: string) =>
    apiFetch<SceneVersionDetail>(`${SCN}/${id}/versions/${versionId}`),

  /* ---------- HTML_WEBVIEW import ---------- */
  importHtmlScene: (file: File, opts?: { title?: string; eventId?: string }) =>
    htmlUpload<AnimationSceneDetail>(`/api/upload/html-scene${toQuery({
      title: opts?.title,
      eventId: opts?.eventId,
    })}`, "POST", file),
  replaceHtmlScene: (id: string, file: File, expectedRowVersion?: number) =>
    htmlUpload<AnimationSceneDetail>(
      `/api/upload/html-scene/${id}${toQuery({ expectedRowVersion })}`,
      "PUT",
      file,
    ),
  /**
   * Lấy HTML nháp để hiển thị trong iframe sandbox: fetch bằng Bearer qua
   * /api/proxy (JSON cap chỉ giới request body, response text/html không bị
   * giới hạn) → caller bọc blob URL. Không bao giờ điều hướng iframe tới URL
   * backend trực tiếp — session cookie/JWT không được rò rỉ vào document.
   */
  fetchHtmlDraft: async (id: string): Promise<Blob> => {
    const token = authStore.getAccessToken();
    const res = await fetch(`/api/proxy${SCN}/${id}/html-draft`, {
      headers: token ? { authorization: `Bearer ${token}` } : undefined,
      cache: "no-store",
    });
    if (!res.ok) {
      const body = await res.json().catch(() => null);
      throw ApiClientError.from(body, res.status);
    }
    return res.blob();
  },
};

/**
 * Multipart upload qua /api/upload/* (không phải /api/proxy — cap JSON 2MiB
 * quá nhỏ cho file HTML 15MB). Gắn access token từ authStore + 1 lần
 * refresh-retry như apiFetch.
 */
async function htmlUpload<T>(path: string, method: string, file: File): Promise<T> {
  const send = async (): Promise<Response> => {
    const token = authStore.getAccessToken();
    const fd = new FormData();
    fd.append("file", file, file.name);
    return fetch(path, {
      method,
      headers: token ? { authorization: `Bearer ${token}` } : undefined,
      body: fd,
    });
  };
  let res = await send();
  if (res.status === 401) {
    const refreshed = await coordinatedRefresh();
    if (refreshed) res = await send();
    else {
      authStore.clear();
      if (typeof window !== "undefined") window.location.assign("/login");
    }
  }
  const body = await res.json().catch(() => null);
  if (!res.ok) throw ApiClientError.from(body, res.status);
  return body as T;
}
