export type HeritageBackgroundMode = "heritage_fade" | "normal" | "none";

export type HeritageTintPreset =
  | "warm"
  | "sepia"
  | "cool"
  | "neutral"
  | "none";

export interface HeritageBackgroundConfig {
  backgroundAssetId?: string | null;
  backgroundImageUrl?: string | null;
  backgroundMode: HeritageBackgroundMode;
  focusX: number;
  focusY: number;
  imageOpacity: number;
  fadeStrength: number;
  tintPreset: HeritageTintPreset;
  enabled: boolean;
}

export interface HeritagePresetDefinition {
  id: HeritageBackgroundMode;
  label: string;
  badge?: string;
  description: string;
  defaults: Pick<
    HeritageBackgroundConfig,
    | "backgroundMode"
    | "focusX"
    | "focusY"
    | "imageOpacity"
    | "fadeStrength"
    | "tintPreset"
    | "enabled"
  >;
}

export const HERITAGE_BACKGROUND_PRESETS: readonly HeritagePresetDefinition[] = [
  {
    id: "none",
    label: "Giấy cổ",
    description:
      "Nền màu kem giấy dó, họa tiết mây cổ và Đông Sơn nhẹ, không dùng ảnh động.",
    defaults: {
      backgroundMode: "none",
      focusX: 0.5,
      focusY: 0.35,
      imageOpacity: 0.55,
      fadeStrength: 0.8,
      tintPreset: "warm",
      enabled: true,
    },
  },
  {
    id: "heritage_fade",
    label: "Heritage Fade",
    badge: "Mặc định",
    description:
      "Ảnh rõ hơn ở phần trên, chuyển dần xuống nền giấy cổ, tông màu ấm, giữ chữ đọc rõ.",
    defaults: {
      backgroundMode: "heritage_fade",
      focusX: 0.5,
      focusY: 0.35,
      imageOpacity: 0.55,
      fadeStrength: 0.8,
      tintPreset: "warm",
      enabled: true,
    },
  },
  {
    id: "normal",
    label: "Ảnh minh họa",
    description:
      "Ảnh hiển thị rõ nét trong vùng hero/card, không áp dụng hiệu ứng chìm quá mạnh.",
    defaults: {
      backgroundMode: "normal",
      focusX: 0.5,
      focusY: 0.35,
      imageOpacity: 0.85,
      fadeStrength: 0.35,
      tintPreset: "neutral",
      enabled: true,
    },
  },
] as const;

export const HERITAGE_TINT_OPTIONS: readonly {
  value: HeritageTintPreset;
  label: string;
  swatch: string;
}[] = [
  { value: "warm", label: "Ấm di sản", swatch: "#E0AE45" },
  { value: "sepia", label: "Hoài cổ", swatch: "#A97932" },
  { value: "neutral", label: "Trung tính", swatch: "#8C8077" },
  { value: "cool", label: "Dịu mát", swatch: "#247D78" },
  { value: "none", label: "Nguyên bản", swatch: "#F8F0E0" },
] as const;

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function extractHeritageAssetId(
  raw: string | null | undefined,
): string | null {
  const trimmed = raw?.trim() ?? "";
  if (!trimmed) return null;
  if (UUID_RE.test(trimmed)) return trimmed;
  const match = trimmed.match(
    /^\/api\/v1\/(?:admin\/)?assets\/([0-9a-f-]{36})\/content$/i,
  );
  const candidate = match?.[1];
  return candidate && UUID_RE.test(candidate) ? candidate : null;
}

export function defaultHeritageBackgroundConfig(): HeritageBackgroundConfig {
  return {
    backgroundAssetId: null,
    backgroundImageUrl: null,
    backgroundMode: "none",
    focusX: 0.5,
    focusY: 0.35,
    imageOpacity: 0.55,
    fadeStrength: 0.8,
    tintPreset: "warm",
    enabled: true,
  };
}

function clampUnit(value: unknown, fallback: number): number {
  if (typeof value !== "number" || Number.isNaN(value) || !Number.isFinite(value)) {
    return fallback;
  }
  return Math.round(Math.max(0, Math.min(1, value)) * 100) / 100;
}

export function normalizeHeritageBackgroundConfig(
  raw?: Partial<HeritageBackgroundConfig> | null,
): HeritageBackgroundConfig {
  if (!raw) {
    return defaultHeritageBackgroundConfig();
  }
  const assetId =
    extractHeritageAssetId(raw.backgroundAssetId) ??
    extractHeritageAssetId(raw.backgroundImageUrl);
  const trimmedUrl = raw.backgroundImageUrl?.trim() || null;
  const resolvedUrl = assetId
    ? `/api/v1/assets/${assetId}/content`
    : trimmedUrl;
  const hasImage = Boolean(resolvedUrl);

  const validModes: HeritageBackgroundMode[] = [
    "heritage_fade",
    "normal",
    "none",
  ];
  const mode: HeritageBackgroundMode =
    raw.backgroundMode && validModes.includes(raw.backgroundMode)
      ? raw.backgroundMode
      : hasImage
        ? "heritage_fade"
        : "none";

  const validTints: HeritageTintPreset[] = [
    "warm",
    "sepia",
    "cool",
    "neutral",
    "none",
  ];
  const tint: HeritageTintPreset =
    raw.tintPreset && validTints.includes(raw.tintPreset)
      ? raw.tintPreset
      : "warm";

  return {
    backgroundAssetId: assetId,
    backgroundImageUrl: resolvedUrl,
    backgroundMode: mode,
    focusX: clampUnit(raw.focusX, 0.5),
    focusY: clampUnit(raw.focusY, 0.35),
    imageOpacity: clampUnit(raw.imageOpacity, mode === "normal" ? 0.85 : 0.55),
    fadeStrength: clampUnit(raw.fadeStrength, mode === "normal" ? 0.35 : 0.8),
    tintPreset: tint,
    enabled: raw.enabled ?? true,
  };
}

/**
 * Applies a preset while preserving the currently selected image.
 */
export function applyHeritagePreset(
  current: HeritageBackgroundConfig,
  presetId: HeritageBackgroundMode,
): HeritageBackgroundConfig {
  const preset =
    HERITAGE_BACKGROUND_PRESETS.find((p) => p.id === presetId) ??
    HERITAGE_BACKGROUND_PRESETS[1]!;
  return {
    ...current,
    ...preset.defaults,
    backgroundAssetId: current.backgroundAssetId ?? null,
    backgroundImageUrl: current.backgroundImageUrl ?? null,
  };
}

/**
 * Replaces or clears the background image without losing focus/opacity/fade/tint settings.
 * If an image is added when mode was "none", switches automatically to "heritage_fade".
 * If image is removed, switches mode to "none".
 */
export function updateHeritageBackgroundImage(
  current: HeritageBackgroundConfig,
  assetId: string | null,
  imageUrl?: string | null,
): HeritageBackgroundConfig {
  const resolvedAssetId = extractHeritageAssetId(assetId) ?? extractHeritageAssetId(imageUrl);
  const resolvedUrl = resolvedAssetId
    ? `/api/v1/assets/${resolvedAssetId}/content`
    : imageUrl?.trim() || null;

  if (!resolvedUrl) {
    return {
      ...current,
      backgroundAssetId: null,
      backgroundImageUrl: null,
      backgroundMode: "none",
    };
  }

  return {
    ...current,
    backgroundAssetId: resolvedAssetId,
    backgroundImageUrl: resolvedUrl,
    backgroundMode:
      current.backgroundMode === "none" ? "heritage_fade" : current.backgroundMode,
    enabled: true,
  };
}
