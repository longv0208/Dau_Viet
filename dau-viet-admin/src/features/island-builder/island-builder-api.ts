import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminAsset } from "@/lib/dto/evidence";

export interface LayoutSummaryDto {
  id: string;
  layoutKey: string;
  title: string;
  description: string | null;
  themeKey: string | null;
  canvasWidth: number;
  canvasHeight: number;
  isDefault: boolean;
  versionCount: number;
  publishedVersionId: string | null;
  publishedVersionNumber: number | null;
  latestDraftVersionId: string | null;
  latestDraftVersionNumber: number | null;
  updatedAt: string;
}

export interface VersionSummaryDto {
  id: string;
  definitionId: string;
  versionNumber: number;
  status: "DRAFT" | "PUBLISHED" | "ARCHIVED";
  rowVersion: number;
  slotCount: number;
  regionCount: number;
  layerCount: number;
  publishedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface LayoutDetailDto {
  id: string;
  layoutKey: string;
  title: string;
  description: string | null;
  themeKey: string | null;
  canvasWidth: number;
  canvasHeight: number;
  isDefault: boolean;
  createdAt: string;
  updatedAt: string;
  versions: VersionSummaryDto[];
}

export interface RegionDto {
  id?: string | null;
  regionCode: string;
  unlockTier: number;
  label: string | null;
  boundsJson: string | null;
  sortOrder: number;
}

export interface SceneLayerDto {
  id?: string | null;
  layerKey: string;
  layerType:
    | "ANIMATED_WATER"
    | "STATIC_IMAGE"
    | "AMBIENT_OVERLAY"
    | "REGION_OVERLAY"
    | "ITEM_LAYER"
    | "FALLBACK_GRAPHICS";
  renderOrder: number;
  assetRef: string | null;
  visibilityRuleJson: string | null;
}

export interface SlotDto {
  id?: string | null;
  slotIndex: number;
  stableSlotKey: string;
  regionCode: string | null;
  tierRequired: number;
  coordX: number;
  coordY: number;
  zIndex: number;
  anchorX: number;
  anchorY: number;
  widthNorm: number;
  heightNorm: number;
  allowedCategories: string[];
}

export interface VersionDetailDto {
  id: string;
  definitionId: string;
  layoutKey: string;
  layoutTitle: string;
  themeKey: string | null;
  canvasWidth: number;
  canvasHeight: number;
  isDefaultLayout: boolean;
  versionNumber: number;
  status: "DRAFT" | "PUBLISHED" | "ARCHIVED";
  rowVersion: number;
  publishedAt: string | null;
  createdAt: string;
  updatedAt: string;
  regions: RegionDto[];
  sceneLayers: SceneLayerDto[];
  slots: SlotDto[];
}

export interface ValidationErrorDto {
  objectType: "VERSION" | "REGION" | "SLOT" | "SCENE_LAYER";
  objectKey: string;
  field: string;
  code: string;
  message: string;
}

export interface ValidationReportDto {
  versionId: string;
  valid: boolean;
  errors: ValidationErrorDto[];
}

export interface CreateLayoutPayload {
  layoutKey: string;
  title: string;
  description?: string | null;
  themeKey?: string | null;
  canvasWidth?: number;
  canvasHeight?: number;
  isDefault?: boolean;
}

export interface UpdateLayoutPayload {
  title?: string;
  description?: string | null;
  themeKey?: string | null;
  canvasWidth?: number;
  canvasHeight?: number;
  isDefault?: boolean;
}

export interface UpdateDraftSnapshotPayload {
  expectedRevision?: number | null;
  canvasWidth?: number;
  canvasHeight?: number;
  themeKey?: string | null;
  regions: RegionDto[];
  sceneLayers: SceneLayerDto[];
  slots: SlotDto[];
}

export const islandBuilderApi = {
  listLayouts: () =>
    apiFetch<LayoutSummaryDto[]>("/admin/island-layouts"),

  getLayout: (layoutId: string) =>
    apiFetch<LayoutDetailDto>(`/admin/island-layouts/${layoutId}`),

  createLayout: (payload: CreateLayoutPayload) =>
    apiFetch<LayoutDetailDto>("/admin/island-layouts", {
      method: "POST",
      body: JSON.stringify(payload),
    }),

  updateLayout: (layoutId: string, payload: UpdateLayoutPayload) =>
    apiFetch<LayoutDetailDto>(`/admin/island-layouts/${layoutId}`, {
      method: "PATCH",
      body: JSON.stringify(payload),
    }),

  listVersions: (layoutId: string) =>
    apiFetch<VersionSummaryDto[]>(`/admin/island-layouts/${layoutId}/versions`),

  createDraft: (layoutId: string) =>
    apiFetch<VersionDetailDto>(`/admin/island-layouts/${layoutId}/versions`, {
      method: "POST",
    }),

  getVersion: (versionId: string) =>
    apiFetch<VersionDetailDto>(`/admin/island-layouts/versions/${versionId}`),

  saveDraftSnapshot: (versionId: string, payload: UpdateDraftSnapshotPayload) =>
    apiFetch<VersionDetailDto>(`/admin/island-layouts/versions/${versionId}`, {
      method: "PUT",
      body: JSON.stringify(payload),
    }),

  cloneVersion: (versionId: string) =>
    apiFetch<VersionDetailDto>(
      `/admin/island-layouts/versions/${versionId}/clone`,
      { method: "POST" },
    ),

  validateVersion: (versionId: string) =>
    apiFetch<ValidationReportDto>(
      `/admin/island-layouts/versions/${versionId}/validate`,
    ),

  publishVersion: (versionId: string, expectedRevision?: number | null) =>
    apiFetch<VersionDetailDto>(
      `/admin/island-layouts/versions/${versionId}/publish`,
      {
        method: "POST",
        body: JSON.stringify({ expectedRevision: expectedRevision ?? null }),
      },
    ),

  archiveVersion: (versionId: string, expectedRevision?: number | null) =>
    apiFetch<VersionDetailDto>(
      `/admin/island-layouts/versions/${versionId}/archive`,
      {
        method: "POST",
        body: JSON.stringify({ expectedRevision: expectedRevision ?? null }),
      },
    ),

  listAssets: (page = 0, size = 48) =>
    apiFetch<PageResponse<AdminAsset>>(
      `/admin/assets${toQuery({ page, size })}`,
    ),
};

export interface ParsedRegionBounds {
  x: number;
  y: number;
  width: number;
  height: number;
}

export function parseRegionBounds(boundsJson: string | null): ParsedRegionBounds {
  if (!boundsJson) {
    return { x: 0.05, y: 0.1, width: 0.9, height: 0.25 };
  }
  try {
    const parsed = JSON.parse(boundsJson);
    return {
      x: typeof parsed.x === "number" ? parsed.x : 0.05,
      y: typeof parsed.y === "number" ? parsed.y : 0.1,
      width: typeof parsed.width === "number" ? parsed.width : 0.9,
      height: typeof parsed.height === "number" ? parsed.height : 0.25,
    };
  } catch {
    return { x: 0.05, y: 0.1, width: 0.9, height: 0.25 };
  }
}

export function serializeRegionBounds(b: ParsedRegionBounds): string {
  return JSON.stringify({
    x: Number(b.x.toFixed(4)),
    y: Number(b.y.toFixed(4)),
    width: Number(b.width.toFixed(4)),
    height: Number(b.height.toFixed(4)),
  });
}

export interface ParsedVisibilityRule {
  minTier: number;
  maxTier: number;
}

export function parseVisibilityRule(
  json: string | null,
): ParsedVisibilityRule {
  if (!json) return { minTier: 1, maxTier: 3 };
  try {
    const parsed = JSON.parse(json);
    return {
      minTier: typeof parsed.minTier === "number" ? parsed.minTier : 1,
      maxTier: typeof parsed.maxTier === "number" ? parsed.maxTier : 3,
    };
  } catch {
    return { minTier: 1, maxTier: 3 };
  }
}

export function serializeVisibilityRule(r: ParsedVisibilityRule): string {
  return JSON.stringify({
    minTier: r.minTier,
    maxTier: r.maxTier,
  });
}
