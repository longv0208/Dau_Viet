/** GAME-06 — gamification CMS DTOs (policy, dossier, rule). */

export type PolicyStatus = "DRAFT" | "PUBLISHED" | "ARCHIVED";
export type DossierType = "PERSON" | "LOCATION" | "ARTIFACT" | "CONTEXT";
export type DossierStatus = "DRAFT" | "PUBLISHED" | "ARCHIVED";

/* ---------- completion policy (Module A) ---------- */

export interface AdminCompletionPolicy {
  id: string;
  eventId: string;
  policyVersion: number;
  status: PolicyStatus;
  requiredLessonIds: string[];
  optionalLessonIds: string[];
  masteryThreshold: number | null;
  publishedAt: string | null;
  createdAt: string;
}

export interface AdminCompletionPolicyUpsert {
  requiredLessonIds: string[];
  optionalLessonIds: string[];
  masteryThreshold: number | null;
  expectedPolicyVersion?: number | null;
}

export interface PolicyIssue {
  code: string;
  message: string;
  field?: string | null;
}

export interface PolicyDiff {
  from: PolicySnapshot | null;
  to: PolicySnapshot | null;
}

export interface PolicySnapshot {
  policyVersion: number;
  requiredCount: number;
  optionalCount: number;
  masteryThreshold: number | null;
  requiredAdded: string[];
  requiredRemoved: string[];
}

export interface AdminPolicyValidation {
  valid: boolean;
  errors: PolicyIssue[];
  warnings: string[];
  diff: PolicyDiff | null;
}

/* ---------- dossiers (Module B) ---------- */

export interface DossierSource {
  title: string;
  author?: string | null;
  citation?: string | null;
  url?: string | null;
  reliability?: "HIGH" | "MEDIUM" | "LOW" | "UNASSESSED" | null;
}

export interface AdminDossierSummary {
  id: string;
  canonicalCode: string;
  dossierType: DossierType;
  title: string;
  summary: string | null;
  status: DossierStatus;
  dossierVersion: number;
  assetId: string | null;
  eventCount: number;
  updatedAt: string;
}

export interface AdminDossierDetail {
  id: string;
  canonicalCode: string;
  dossierType: DossierType;
  title: string;
  summary: string | null;
  description: string | null;
  source: DossierSource | null;
  assetId: string | null;
  status: DossierStatus;
  dossierVersion: number;
  rowVersion: number;
  pendingChanges: boolean;
  events: { eventId: string; eventTitle: string; displayOrder: number }[];
  versions: {
    version: number;
    status: string;
    publishedAt: string;
    publishedBy: string | null;
  }[];
  createdAt: string;
  updatedAt: string;
}

export interface AdminDossierCreate {
  canonicalCode: string;
  dossierType: DossierType;
  title: string;
  summary?: string | null;
  description?: string | null;
  source?: DossierSource | null;
  assetId?: string | null;
}

export interface AdminDossierUpdate {
  dossierType?: DossierType;
  title?: string;
  summary?: string | null;
  description?: string | null;
  source?: DossierSource | null;
  assetId?: string | null;
  clearAsset?: boolean;
  expectedRowVersion?: number;
}

export interface AdminEventDossierLink {
  dossierId: string;
  canonicalCode: string;
  title: string;
  dossierType: DossierType;
  status: DossierStatus;
  displayOrder: number;
}

export interface AdminEventDossierLinkRequest {
  dossierId: string;
  displayOrder: number;
}

/* ---------- rule validate/history (Module C) ---------- */

export interface AdminRuleValidationIssue {
  code: string;
  message: string;
  field?: string | null;
}

/** POST /admin/items/{id}/rule/validate — dry-run, không ghi DB. */
export interface AdminRuleValidation {
  valid: boolean;
  errors: AdminRuleValidationIssue[];
  warnings: string[];
  normalizedCondition: unknown | null;
  scope: string;
  acceptsRule: boolean;
}

/** GET /admin/items/{id}/rule/history — mọi revision đã publish. */
export interface AdminRuleHistoryEntry {
  id: string;
  ruleType: string;
  lessonId: string | null;
  threshold: number | null;
  /** Schema payload: 1 = cột phẳng, 2 = AST. */
  ruleVersion: number;
  /** Thứ tự publish per-item (monotonic). */
  revision: number;
  active: boolean;
  conditionJson: unknown | null;
  ruleMetadata: unknown | null;
  createdAt: string;
  /** Số user_inventory row provenance trỏ về rule này. */
  grantCount: number;
}

/** POST /admin/rewards/reconcile-unlocks?batchSize= (batched response). */
export interface ReconcileResult {
  itemsGranted: number;
  usersScanned?: number;
  batches?: number;
}
