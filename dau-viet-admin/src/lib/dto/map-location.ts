/** Mirrors com.dauviet.map.admin.dto.* */

export type MapLocationStatus = "DRAFT" | "PUBLISHED" | "ARCHIVED";

export type MapLocationKind =
  | "HERITAGE_SITE"
  | "BATTLEFIELD"
  | "ANCIENT_CAPITAL"
  | "ARCHAEOLOGICAL_SITE"
  | "MEMORIAL"
  | "SCHEMATIC_REGION";

export type CoordinatePrecision = "EXACT" | "APPROXIMATE" | "SCHEMATIC_ONLY";

export type MapLocationVisibility = "ALWAYS_VISIBLE" | "HIDDEN_UNTIL_UNLOCKED";

export type UnlockRuleMode = "NONE" | "ANY" | "ALL";

export type MapLocationEventRole = "PRIMARY" | "RELATED";

export type LocationMediaType =
  | "IMAGE_2D"
  | "PANORAMA_360"
  | "AUDIO_GUIDE"
  | "DOCUMENTARY_CLIP";

export type LocationMediaVisibility = "PUBLIC_PREVIEW" | "UNLOCKED_ONLY";

/** AdminMapLocationResponse — nested under /admin/events/{eventId}/map-locations. */
export interface AdminMapLocation {
  id: string;
  eventId: string;
  title: string;
  description: string | null;
  latitude: number;
  longitude: number;
  unlockLessonId: string | null;
  unlockLessonTitle: string | null;
  displayOrder: number;
  status: MapLocationStatus;
  /** Đã từng publish ≥1 lần → unlockLessonId immutable (backend enforced). */
  everPublished: boolean;
  rowVersion: number;
  createdAt: string;
  updatedAt: string;
}

/** AdminMapLocationRequest — POST/PATCH under /admin/events/{eventId}/map-locations. */
export interface AdminMapLocationRequest {
  title: string;
  description?: string;
  latitude: number;
  longitude: number;
  /** null/absent = always AVAILABLE to learners. */
  unlockLessonId?: string | null;
  displayOrder?: number;
}

export interface EventLinkView {
  eventId: string;
  title: string | null;
  yearLabel: string | null;
  role: MapLocationEventRole;
  sortOrder: number;
}

export interface EventLinkInput {
  eventId: string;
  role: MapLocationEventRole;
  sortOrder: number;
}

export interface UnlockLessonView {
  lessonId: string;
  title: string | null;
  status: string | null;
  sortOrder: number;
}

export interface ReplaceUnlockLessonsRequest {
  unlockRuleMode: UnlockRuleMode;
  lessonIds: string[];
}

export interface MediaView {
  id: string;
  mediaType: LocationMediaType;
  title: string | null;
  caption: string | null;
  assetId: string | null;
  assetUrl: string | null;
  externalUrl: string | null;
  visibility: LocationMediaVisibility;
  sortOrder: number;
}

export interface MediaInput {
  mediaType: LocationMediaType;
  title?: string;
  caption?: string;
  assetId?: string | null;
  externalUrl?: string | null;
  visibility: LocationMediaVisibility;
  sortOrder: number;
}

export interface StandaloneLocationResponse {
  id: string;
  slug: string | null;
  eventId: string | null;
  title: string;
  shortSummary: string | null;
  description: string | null;
  kind: MapLocationKind;
  latitude: number;
  longitude: number;
  coordinatePrecision: CoordinatePrecision;
  visibility: MapLocationVisibility;
  unlockRuleMode: UnlockRuleMode;
  coverAssetId: string | null;
  mapAssetId?: string | null;
  displayOrder: number;
  status: MapLocationStatus;
  everPublished: boolean;
  rowVersion: number;
  createdAt: string;
  updatedAt: string;
  events: EventLinkView[];
  unlockLessons: UnlockLessonView[];
  media: MediaView[];
}

export interface StandaloneLocationRequest {
  slug?: string | null;
  title: string;
  shortSummary?: string | null;
  description?: string | null;
  kind?: MapLocationKind;
  latitude: number;
  longitude: number;
  coordinatePrecision?: CoordinatePrecision;
  visibility?: MapLocationVisibility;
  unlockRuleMode?: UnlockRuleMode;
  coverAssetId?: string | null;
  mapAssetId?: string | null;
  displayOrder?: number;
}

export const LOCATION_KIND_LABELS: Record<MapLocationKind, string> = {
  HERITAGE_SITE: "Di tích lịch sử",
  BATTLEFIELD: "Chiến trường cổ",
  ANCIENT_CAPITAL: "Kinh đô cổ",
  ARCHAEOLOGICAL_SITE: "Khu khảo cổ",
  MEMORIAL: "Đài tưởng niệm / Đền thờ",
  SCHEMATIC_REGION: "Vùng chiến lược / Bản đồ ước lệ",
};

export const COORDINATE_PRECISION_LABELS: Record<CoordinatePrecision, string> = {
  EXACT: "Chính xác (Tọa độ điểm)",
  APPROXIMATE: "Tương đối (Khu vực lân cận)",
  SCHEMATIC_ONLY: "Ước lệ trên bản đồ minh họa",
};

export const LOCATION_VISIBILITY_LABELS: Record<MapLocationVisibility, string> = {
  ALWAYS_VISIBLE: "Luôn hiển thị mốc trên bản đồ (Hiện trạng thái khóa/mở)",
  HIDDEN_UNTIL_UNLOCKED: "Ẩn hoàn toàn cho tới khi học viên mở khóa",
};

export const UNLOCK_RULE_MODE_LABELS: Record<UnlockRuleMode, string> = {
  NONE: "Luôn mở (Không yêu cầu hoàn thành bài học)",
  ANY: "Mở ngay khi hoàn thành ÍT NHẤT 1 bài học (OR / ANY)",
  ALL: "Chỉ mở khi hoàn thành TẤT CẢ bài học liên kết (AND / ALL)",
};

export const MEDIA_TYPE_LABELS: Record<LocationMediaType, string> = {
  IMAGE_2D: "Tranh / Ảnh tư liệu 2D",
  PANORAMA_360: "Không gian 360° / Panorama",
  AUDIO_GUIDE: "Thuyết minh âm thanh (Audio Guide)",
  DOCUMENTARY_CLIP: "Phim tư liệu ngắn (Video Clip)",
};

export const MEDIA_VISIBILITY_LABELS: Record<LocationMediaVisibility, string> = {
  PUBLIC_PREVIEW: "Xem trước công khai (Kể cả khi đang khóa)",
  UNLOCKED_ONLY: "Chỉ xem được sau khi mở khóa địa điểm",
};

export interface HeritagePresetIllustration {
  key: string;
  assetId: string;
  title: string;
  url: string;
  suggestedKind: MapLocationKind;
  caption: string;
}

export const HERITAGE_PRESET_ILLUSTRATIONS: HeritagePresetIllustration[] = [
  {
    key: "den-hung-phong-chau",
    assetId: "d7a70000-0000-4000-8000-000000000001",
    title: "Khu di tích Đền Hùng — Phong Châu (Văn Lang)",
    url: "/heritage/den-hung-phong-chau.jpg",
    suggestedKind: "ANCIENT_CAPITAL",
    caption: "Đền Hùng trên núi Nghĩa Lĩnh — Kinh đô Phong Châu thời các Vua Hùng dựng nước Văn Lang.",
  },
  {
    key: "me-linh-hai-ba-trung",
    assetId: "d7a70000-0000-4000-8000-000000000002",
    title: "Thành cổ Mê Linh — Đền Hai Bà Trưng (Năm 40)",
    url: "/heritage/me-linh-hai-ba-trung.jpg",
    suggestedKind: "HERITAGE_SITE",
    caption: "Kinh đô Mê Linh nơi Hai Bà Trưng phất cờ khởi nghĩa giành quyền tự chủ năm 40.",
  },
  {
    key: "bai-coc-bach-dang",
    assetId: "d7a70000-0000-4000-8000-000000000003",
    title: "Bãi cọc Bạch Đằng Giang (Năm 938)",
    url: "/heritage/bai-coc-bach-dang.jpg",
    suggestedKind: "BATTLEFIELD",
    caption: "Trận địa cọc gỗ bịt sắt của Ngô Quyền trên cửa sông Bạch Đằng năm 938.",
  },
  {
    key: "hoang-thanh-thang-long",
    assetId: "d7a70000-0000-4000-8000-000000000004",
    title: "Hoàng thành Thăng Long — Đoan Môn (Năm 1010)",
    url: "/heritage/hoang-thanh-thang-long.jpg",
    suggestedKind: "ANCIENT_CAPITAL",
    caption: "Kinh đô Thăng Long thời Lý Thái Tổ ban Chiếu dời đô năm 1010.",
  },
  {
    key: "phong-tuyen-nhu-nguyet",
    assetId: "d7a70000-0000-4000-8000-000000000005",
    title: "Phòng tuyến sông Như Nguyệt (Năm 1077)",
    url: "/heritage/phong-tuyen-nhu-nguyet.jpg",
    suggestedKind: "BATTLEFIELD",
    caption: "Phòng tuyến lũy tre và thành đất bên bờ sông Cầu của Thái úy Lý Thường Kiệt năm 1077.",
  },
  {
    key: "doi-a1-dien-bien-phu",
    assetId: "d7a70000-0000-4000-8000-000000000006",
    title: "Đồi A1 & Lòng chảo Mường Thanh — Điện Biên Phủ (Năm 1954)",
    url: "/heritage/doi-a1-dien-bien-phu.jpg",
    suggestedKind: "BATTLEFIELD",
    caption: "Cứ điểm Đồi A1 lịch sử trong Chiến dịch Điện Biên Phủ năm 1954.",
  },
];

export interface HeritagePresetMap {
  key: string;
  assetId: string;
  title: string;
  shortLabel: string;
  url: string;
}

export const HERITAGE_PRESET_MAPS: HeritagePresetMap[] = [
  {
    key: "map-van-lang",
    assetId: "d7a90000-0000-4000-8000-000000000001",
    title: "Bản đồ Nước Văn Lang Thời Các Vua Hùng",
    shortLabel: "Bản đồ Văn Lang",
    url: "/maps/map_van_lang.jpg",
  },
  {
    key: "map-hai-ba-trung",
    assetId: "d7a90000-0000-4000-8000-000000000002",
    title: "Bản đồ Khởi Nghĩa Hai Bà Trưng (Năm 40)",
    shortLabel: "Bản đồ Hai Bà Trưng",
    url: "/maps/map_hai_ba_trung.jpg",
  },
  {
    key: "map-bach-dang",
    assetId: "d7a90000-0000-4000-8000-000000000003",
    title: "Bản đồ Thủy Chiến Bạch Đằng Giang 938",
    shortLabel: "Bản đồ Bạch Đằng 938",
    url: "/maps/dv_MAP_ngoquyen_bachdang-base_v01.jpg",
  },
  {
    key: "map-nhu-nguyet",
    assetId: "d7a90000-0000-4000-8000-000000000004",
    title: "Bản đồ Phòng Tuyến Sông Như Nguyệt 1077",
    shortLabel: "Bản đồ Như Nguyệt 1077",
    url: "/maps/map_nhu_nguyet.jpg",
  },
  {
    key: "map-dien-bien-phu",
    assetId: "d7a90000-0000-4000-8000-000000000005",
    title: "Bản đồ Chiến Dịch Điện Biên Phủ 1954",
    shortLabel: "Bản đồ Điện Biên Phủ",
    url: "/maps/map_dien_bien_phu.jpg",
  },
  {
    key: "map-vietnam-journey",
    assetId: "d7a90000-0000-4000-8000-000000000006",
    title: "Bản đồ Hành Trình Lịch Sử Việt Nam",
    shortLabel: "Bản đồ Hành trình VN",
    url: "/maps/vietnam_journey_map_bg.jpg",
  },
];

export function resolvePresetIllustrationByAssetId(
  assetId: string | null | undefined,
): HeritagePresetIllustration | null {
  if (!assetId) return null;
  const normalized = assetId.trim().toLowerCase();
  return (
    HERITAGE_PRESET_ILLUSTRATIONS.find(
      (item) => item.assetId.toLowerCase() === normalized,
    ) ?? null
  );
}

export function resolvePresetMapByAssetId(
  assetId: string | null | undefined,
): HeritagePresetMap | null {
  if (!assetId) return null;
  const normalized = assetId.trim().toLowerCase();
  return (
    HERITAGE_PRESET_MAPS.find(
      (item) => item.assetId.toLowerCase() === normalized,
    ) ?? null
  );
}

export function resolveHeritageFallbackIllustration(
  slug: string | null | undefined,
  title: string,
): string {
  const haystack = `${slug ?? ""} ${title}`.toLowerCase();
  if (
    haystack.includes("bach-dang") ||
    haystack.includes("bạch đằng") ||
    haystack.includes("nam-trieu") ||
    haystack.includes("nam triệu") ||
    haystack.includes("yên giang")
  ) {
    return "/heritage/bai-coc-bach-dang.jpg";
  }
  if (
    haystack.includes("hai-ba-trung") ||
    haystack.includes("mê linh") ||
    haystack.includes("me-linh") ||
    haystack.includes("hát môn") ||
    haystack.includes("hat-mon") ||
    haystack.includes("sông hát") ||
    haystack.includes("luy lâu")
  ) {
    return "/heritage/me-linh-hai-ba-trung.jpg";
  }
  if (
    haystack.includes("thang-long") ||
    haystack.includes("thăng long") ||
    haystack.includes("đoan môn") ||
    haystack.includes("nhà hồ") ||
    haystack.includes("nha-ho") ||
    haystack.includes("huế") ||
    haystack.includes("hue") ||
    haystack.includes("thiên mụ") ||
    haystack.includes("minh mạng") ||
    haystack.includes("hội an") ||
    haystack.includes("hoi-an")
  ) {
    return "/heritage/hoang-thanh-thang-long.jpg";
  }
  if (
    haystack.includes("nhu-nguyet") ||
    haystack.includes("như nguyệt") ||
    haystack.includes("sông cầu") ||
    haystack.includes("đền xà") ||
    haystack.includes("nam quốc sơn hà")
  ) {
    return "/heritage/phong-tuyen-nhu-nguyet.jpg";
  }
  if (
    haystack.includes("dien-bien") ||
    haystack.includes("điện biên") ||
    haystack.includes("a1") ||
    haystack.includes("castries") ||
    haystack.includes("mường thanh")
  ) {
    return "/heritage/doi-a1-dien-bien-phu.jpg";
  }
  return "/heritage/den-hung-phong-chau.jpg";
}

export function resolveLocationMapPreset(params: {
  mapAssetId?: string | null;
  slug?: string | null;
  title?: string | null;
  eventId?: string | null;
  eventHints?: (string | null | undefined)[];
}): HeritagePresetMap {
  const byAsset = resolvePresetMapByAssetId(params.mapAssetId);
  if (byAsset) return byAsset;

  const haystack = [
    params.slug ?? "",
    params.title ?? "",
    params.eventId ?? "",
    ...(params.eventHints ?? []),
  ]
    .join(" ")
    .toLowerCase();

  if (
    haystack.includes("000000000001") ||
    haystack.includes("bach-dang") ||
    haystack.includes("bạch đằng") ||
    haystack.includes("nam-trieu") ||
    haystack.includes("nam triệu") ||
    haystack.includes("yên giang") ||
    haystack.includes("938")
  ) {
    return HERITAGE_PRESET_MAPS[2]; // map-bach-dang
  }
  if (
    haystack.includes("000000000002") ||
    haystack.includes("hai-ba-trung") ||
    haystack.includes("hai bà trưng") ||
    haystack.includes("mê linh") ||
    haystack.includes("me-linh") ||
    haystack.includes("hát môn") ||
    haystack.includes("sông hát") ||
    haystack.includes("luy lâu")
  ) {
    return HERITAGE_PRESET_MAPS[1]; // map-hai-ba-trung
  }
  if (
    haystack.includes("000000000003") ||
    haystack.includes("nhu-nguyet") ||
    haystack.includes("như nguyệt") ||
    haystack.includes("sông cầu") ||
    haystack.includes("đền xà") ||
    haystack.includes("1077")
  ) {
    return HERITAGE_PRESET_MAPS[3]; // map-nhu-nguyet
  }
  if (
    haystack.includes("000000000004") ||
    haystack.includes("dien-bien") ||
    haystack.includes("điện biên") ||
    haystack.includes("đồi a1") ||
    haystack.includes("castries") ||
    haystack.includes("mường thanh") ||
    haystack.includes("1954")
  ) {
    return HERITAGE_PRESET_MAPS[4]; // map-dien-bien-phu
  }
  if (
    haystack.includes("000000000005") ||
    haystack.includes("van-lang") ||
    haystack.includes("văn lang") ||
    haystack.includes("đền hùng") ||
    haystack.includes("den-hung") ||
    haystack.includes("hùng vương") ||
    haystack.includes("ngã ba hạc") ||
    haystack.includes("phong châu")
  ) {
    return HERITAGE_PRESET_MAPS[0]; // map-van-lang
  }
  return HERITAGE_PRESET_MAPS[5]; // map-vietnam-journey
}
