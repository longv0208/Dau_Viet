/** TASK-0023 — item catalog + unlock rules DTOs (admin). */

export interface AdminItemRule {
  id: string;
  ruleType: "LESSON_COMPLETED" | "COLLECTION_COUNT" | "LESSON_COUNT";
  lessonId?: string | null;
  threshold?: number | null;
  active: boolean;
}

export interface AdminItem {
  id: string;
  code: string;
  name: string;
  description: string;
  category: string;
  itemType: "HISTORICAL_REPLICA" | "DIGITAL_EDITION" | "COMMEMORATIVE_BADGE";
  rarity: "COMMON" | "UNCOMMON" | "RARE" | "EPIC";
  assetId?: string | null;
  sourceMetadata?: Record<string, unknown> | null;
  active: boolean;
  rowVersion: number;
  rule?: AdminItemRule | null;
}

export interface AdminItemRequest {
  code: string;
  name: string;
  description?: string;
  category: string;
  itemType: AdminItem["itemType"];
  rarity?: AdminItem["rarity"];
  /** Partial update: gửi UUID để đổi ảnh, bỏ qua field = giữ nguyên. */
  assetId?: string | null;
  /** Xoá asset có chủ đích — chỉ cần khi muốn bỏ ảnh mà không gán ảnh mới. */
  clearAsset?: boolean;
  /** Gửi {} để xoá source metadata có chủ đích; bỏ qua field = giữ nguyên. */
  sourceMetadata?: Record<string, unknown> | null;
  active?: boolean;
}

export interface AdminRuleRequest {
  ruleType: AdminItemRule["ruleType"];
  lessonId?: string | null;
  threshold?: number | null;
  active?: boolean;
}
