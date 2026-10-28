import { apiFetch, toQuery } from "@/lib/api-client";
import type { PageResponse } from "@/lib/dto/common";
import type { AdminAsset } from "@/lib/dto/evidence";

export interface LayoutSummaryDto {
  id: string;
  layoutKey: string;
  name: string;
  description: string | null;
  canvasWidth: number;
  canvasHeight: number;
  themeKey: string | null;
  defaultLayout: boolean;
  versionCount: number;
  publishedVersionNumber: number | null;
  publishedVersionId: string | null;
  latestDraftVersionNumber: number | null;
  latestDraftVersionId: string | null;
  latestStatus: string;
  updatedAt: string;
}

export interface VersionSummaryDto {
  id: string;
  definitionId: string;
  versionNumber: number;
  status: "DRAFT" | "PUBLISHED" | "ARCHIVED";
  rowVersion: number;
  publishedAt: string | null;
  archivedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface LayoutDetailDto {
  id: string;
  layoutKey: string;
  name: string;
  description: string | null;
  canvasWidth: number;
  canvasHeight: number;
  themeKey: string | null;
  defaultLayout: boolean;
  createdAt: string;
  updatedAt: string;
  versions: VersionSummaryDto[];
}

export interface TierPolicySummaryDto {
  tier: number;
  slotCount: number;
  requiredLevel: number | null;
}

export type TerrainType =
  | "GRASS"
  | "DIRT"
  | "STONE"
  | "PATH"
  | "DECORATIVE"
  | "WATER";

export interface TileDto {
  key: string;
  row: number;
  col: number;
  terrainType: TerrainType;
  regionCode?: string | null;
  unlockTier: number;
  elevation?: number;
  decorKey?: string | null;
  slotId?: string | null;
}

export interface BoardDto {
  rows: number;
  cols: number;
  tileWidth: number;
  tileHeight: number;
  tiles: TileDto[];
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
  tierRequired: number;
  regionCode: string | null;
  coordX: number;
  coordY: number;
  zIndex: number;
  anchorX: number;
  anchorY: number;
  widthNorm: number;
  heightNorm: number;
  allowedCategories: string[];
  tileRow?: number;
  tileCol?: number;
}

export interface VersionDetailDto {
  id: string;
  definitionId: string;
  layoutKey: string;
  layoutName: string;
  canvasWidth: number;
  canvasHeight: number;
  themeKey: string | null;
  defaultLayout: boolean;
  versionNumber: number;
  status: "DRAFT" | "PUBLISHED" | "ARCHIVED";
  rowVersion: number;
  publishedAt: string | null;
  archivedAt: string | null;
  createdAt: string;
  updatedAt: string;
  regions: RegionDto[];
  slots: SlotDto[];
  sceneLayers: SceneLayerDto[];
  tierPolicies: TierPolicySummaryDto[];
  board?: BoardDto | null;
}

export interface ValidationErrorDto {
  objectType: "POLICY" | "REGION" | "SLOT" | "LAYER";
  objectKey: string;
  field: string;
  code: string;
  message: string;
}

export interface ValidationReportDto {
  valid: boolean;
  errors: ValidationErrorDto[];
}

export interface CreateLayoutPayload {
  layoutKey: string;
  name: string;
  description?: string | null;
  canvasWidth?: number;
  canvasHeight?: number;
  themeKey?: string | null;
  defaultLayout?: boolean;
}

export interface UpdateLayoutPayload {
  name?: string;
  description?: string | null;
  canvasWidth?: number;
  canvasHeight?: number;
  themeKey?: string | null;
  defaultLayout?: boolean;
}

export interface UpdateDraftSnapshotPayload {
  expectedRevision: number;
  regions: RegionDto[];
  slots: SlotDto[];
  sceneLayers: SceneLayerDto[];
  board?: BoardDto | null;
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

  publishVersion: (versionId: string, expectedRevision: number) =>
    apiFetch<VersionDetailDto>(
      `/admin/island-layouts/versions/${versionId}/publish`,
      {
        method: "POST",
        body: JSON.stringify({ expectedRevision }),
      },
    ),

  archiveVersion: (versionId: string, expectedRevision: number) =>
    apiFetch<VersionDetailDto>(
      `/admin/island-layouts/versions/${versionId}/archive`,
      {
        method: "POST",
        body: JSON.stringify({ expectedRevision }),
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
