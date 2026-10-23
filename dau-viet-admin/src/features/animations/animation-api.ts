import { apiFetch, toQuery } from "@/lib/api-client";
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
};
