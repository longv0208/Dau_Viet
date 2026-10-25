/** TASK-0023 — item catalog + unlock rules DTOs (admin). */

/**
 * Rule đang gắn item (active). `ruleType` v1 là loại phẳng; V2 dùng
 * nhãn "RULE_V2" kèm `conditionJson` AST (GAME-05/06).
 */
export interface AdminItemRule {
  id: string;
  ruleType: string;
  lessonId?: string | null;
  threshold?: number | null;
  active: boolean;
  /** 1 = cột phẳng legacy; 2 = AST condition. */
  ruleVersion?: number | null;
  conditionJson?: unknown | null;
  ruleMetadata?: unknown | null;
}

/** Item scope suy ra từ audit trail (ItemRuleScopeResolver). */
export type ItemScope = "UNRESOLVED" | "EVENT_SCOPED" | "GLOBAL";

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
  /** UNRESOLVED | EVENT_SCOPED | GLOBAL — GAME-06 scope banner. */
  scope?: ItemScope | string | null;
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

/**
 * PUT /admin/items/{id}/rule — V1 (ruleType phẳng) hoặc V2 (condition AST,
 * ruleType chỉ là nhãn — server yêu cầu "RULE_V2" hoặc bỏ trống).
 */
export interface AdminRuleRequest {
  ruleType?: string;
  lessonId?: string | null;
  threshold?: number | null;
  active?: boolean;
  /** AST { leaf | {all:[…]} | {any:[…]} } — GAME-06 Rule Builder. */
  condition?: unknown;
}
