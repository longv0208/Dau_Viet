/** Mirrors com.dauviet.animation.api.dto.* + manifest schema V14. */

export type SceneStatus = "DRAFT" | "PUBLISHED" | "ARCHIVED";

/* ---------- Admin DTOs ---------- */

export interface AnimationTemplateDto {
  id: string;
  code: string;
  name: string;
  description: string | null;
  rendererCode: string;
  rendererVersion: number;
  schemaVersion: number;
  capabilitiesJson: string | null;
  defaultConfigJson: string | null;
  thumbnailAssetId: string | null;
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AnimationSceneSummary {
  id: string;
  templateId: string;
  eventId: string | null;
  title: string;
  status: SceneStatus;
  currentVersionId: string | null;
  currentVersionNo: number | null;
  rowVersion: number;
  updatedAt: string;
}

export interface AnimationSceneDetail extends AnimationSceneSummary {
  /** Chuỗi JSON của draft — client JSON.parse trước khi dùng. */
  draftJson: string;
  createdBy: string;
  updatedBy: string;
  createdAt: string;
}

export interface SceneVersionSummary {
  id: string;
  sceneId: string;
  versionNo: number;
  rendererCode: string;
  rendererVersion: number;
  manifestChecksum: string;
  publishedBy: string;
  publishedAt: string;
}

export interface SceneVersionDetail extends SceneVersionSummary {
  snapshotJson: string;
}

export interface SceneFieldError {
  path: string;
  code: string;
  message: string;
}

export interface SceneValidationResult {
  ready: boolean;
  errors: SceneFieldError[];
}

/* ---------- Manifest (draftJson) ---------- */

/** Whitelisted values — khớp AnimationManifestSchema backend. */
export const RENDERER_CODES = ["RIVER_TIDE", "JOURNEY_MAP"] as const;
export const EASINGS = ["linear", "easeIn", "easeOut", "easeInOut", "easeInOutCubic"] as const;
export const EFFECTS = ["HIGHLIGHT", "PULSE", "SHAKE", "FADE_IN", "FADE_OUT", "SHOW_SEQUENCE_SUMMARY", "REVEAL"] as const;
export const INTERACTION_CODES = ["WATER_LEVEL_CONTROL", "TAP_TO_EXPLORE", "PREDICTION"] as const;
export const ASSET_ROLES = ["BACKGROUND", "OBJECT", "THUMBNAIL", "AUDIO", "OVERLAY"] as const;
export const PLAYBACK_MODES = ["AUTO", "STEPPED", "INTERACTIVE"] as const;

export interface ManifestAssetRef {
  id: string;
  assetId: string;
  role: string;
}

export interface ManifestObject {
  id: string;
  type: string;
  position?: { x: number; y: number };
  scale?: number;
  rotation?: number;
  visible?: boolean;
  layer?: number;
}

export interface ManifestStep {
  id: string;
  title: string;
  narration?: string;
  hint?: string;
  durationMs?: number;
  targetState?: Record<string, unknown>;
  easing?: string;
  effects?: string[];
  allowedInteractions?: string[];
}

export interface ManifestPrediction {
  question: string;
  options: { text: string }[];
  explainedOptionIndex: number;
  explanation?: string;
  retryHint?: string;
  revealTargetState?: Record<string, unknown>;
}

export interface RiverStake {
  id: string;
  x: number;
  length: number;
  visible?: boolean;
}

export interface MapLocationDto {
  id: string;
  name: string;
  x: number;
  y: number;
  description?: string;
  contextLabel?: string;
}

export interface MapRouteDto {
  id: string;
  from: string;
  to: string;
  via?: { x: number; y: number }[];
  explanation?: string;
}

export interface AnimationManifest {
  schemaVersion: number;
  rendererCode: string;
  rendererVersion: number;
  title: string;
  learningObjective?: string;
  canvas?: { aspectRatio?: number };
  assets?: ManifestAssetRef[];
  objects?: ManifestObject[];
  initialState?: Record<string, unknown>;
  steps: ManifestStep[];
  interactions?: string[];
  narration?: string;
  prediction?: ManifestPrediction;
  sourceReferences?: { title: string }[];
  disclaimer?: string;
  river?: { stakes?: RiverStake[] };
  map?: {
    locations?: MapLocationDto[];
    routes?: MapRouteDto[];
    backgroundAssetId?: string;
  };
}

/** Draft rỗng hợp lệ tối thiểu cho renderer cho trước. */
export function emptyManifest(rendererCode: string, rendererVersion = 1): AnimationManifest {
  const base: AnimationManifest = {
    schemaVersion: 1,
    rendererCode,
    rendererVersion,
    title: "",
    canvas: { aspectRatio: 1.6 },
    assets: [],
    objects: [],
    initialState: {},
    steps: [],
    interactions: [],
    sourceReferences: [],
    disclaimer: "",
  };
  if (rendererCode === "RIVER_TIDE") base.river = { stakes: [] };
  if (rendererCode === "JOURNEY_MAP") base.map = { locations: [], routes: [] };
  return base;
}
