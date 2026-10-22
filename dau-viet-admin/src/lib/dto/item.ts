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
  assetId?: string | null;
  sourceMetadata?: Record<string, unknown> | null;
  active?: boolean;
}

export interface AdminRuleRequest {
  ruleType: AdminItemRule["ruleType"];
  lessonId?: string | null;
  threshold?: number | null;
  active?: boolean;
}
