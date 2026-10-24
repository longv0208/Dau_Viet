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
export const RENDERER_CODES = ["RIVER_TIDE", "JOURNEY_MAP", "HTML_WEBVIEW"] as const;
export const EASINGS = ["linear", "easeIn", "easeOut", "easeInOut", "easeInOutCubic"] as const;
export const EFFECTS = ["HIGHLIGHT", "PULSE", "SHAKE", "FADE_IN", "FADE_OUT", "SHOW_SEQUENCE_SUMMARY", "REVEAL"] as const;
export const INTERACTION_CODES = ["WATER_LEVEL_CONTROL", "TAP_TO_EXPLORE", "PREDICTION"] as const;
export const ASSET_ROLES = ["BACKGROUND", "OBJECT", "THUMBNAIL", "AUDIO", "OVERLAY"] as const;
export const PLAYBACK_MODES = ["AUTO", "STEPPED", "INTERACTIVE"] as const;

/* ---------- Cinematic v2 (schemaVersion >= 2) ---------- */

/** Step-level effect types — whitelisted in EFFECTS above. Scene-level
 * typed overlays dùng EFFECT_TYPES_V2 riêng (không trùng namespace). */
export const EFFECT_TYPES_V2 = [
  "WATER_RIPPLE", "MIST", "GLOW", "ROUTE_REVEAL", "FADE_IN", "FADE_OUT",
] as const;

export const TRACK_PROPERTIES = [
  "position", "scale", "rotation", "opacity", "visible",
] as const;

export const AUDIO_CUES = ["ENTER", "EXIT", "LOOP"] as const;

/** Top-level keys đánh dấu manifest là v2 — presence => schemaVersion >= 2. */
export const V2_TOP_LEVEL_KEYS = [
  "camera", "tracks", "effects", "audio", "environment",
] as const;

export interface CameraPose {
  x: number; // normalized center 0..1
  y: number;
  zoom: number; // 0.5..3.0
  focusObjectId?: string;
  focusLocationId?: string;
}

export interface CameraStep {
  target: CameraPose;
  durationMs?: number;
  easing?: string;
}

export interface CameraTrack {
  initial: CameraPose;
  steps: CameraStep[]; // steps[i] = pose đích cho step index i
}

export interface Keyframe {
  tMs: number;
  /** position = {x,y}; scale/rotation/opacity = number; visible = boolean. */
  value: unknown;
  easing?: string;
}

export interface ObjectTrack {
  objectId: string;
  property: string; // TRACK_PROPERTIES
  keyframes: Keyframe[];
}

export interface SceneEffect {
  type: string; // EFFECT_TYPES_V2
  stepId?: string;
  durationMs?: number;
  params?: Record<string, unknown>;
}

export interface AudioCue {
  stepId: string;
  assetRef: string; // assets[].id với role=AUDIO
  cue: string; // AUDIO_CUES
  volume?: number; // 0..1
  fadeMs?: number;
}

export interface EnvironmentConfig {
  waterLevel?: number;
  mist?: number; // 0..1
  glow?: number; // 0..1
}

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
  /** Khóa tham chiếu sang assets[].id — chỉ entry role OBJECT mới render ảnh. */
  assetRef?: string;
  /** "rect" | "circle" — shape của khung ảnh (mặc định rect). */
  shape?: string;
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
  /** v2 cinematic — tất cả optional; presence => schemaVersion >= 2. */
  camera?: CameraTrack;
  tracks?: ObjectTrack[];
  effects?: SceneEffect[];
  audio?: AudioCue[];
  environment?: EnvironmentConfig;
  /** HTML_WEBVIEW — metadata file tải lên; bytes không nằm trong manifest. */
  html?: { filename?: string; sizeBytes: number; sha256: string };
}

/** Kiểm tra manifest có v2 keys — validator backend bắt schemaVersion>=2. */
export function manifestHasV2(m: AnimationManifest): boolean {
  return (
    m.camera !== undefined ||
    (m.tracks?.length ?? 0) > 0 ||
    (m.effects?.length ?? 0) > 0 ||
    (m.audio?.length ?? 0) > 0 ||
    m.environment !== undefined
  );
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
