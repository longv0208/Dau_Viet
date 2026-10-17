/** Mirrors com.dauviet.lesson.api.dto.Evidence* + Asset* */

export type EvidenceStatus = "DRAFT" | "APPROVED" | "ARCHIVED";
export type EvidenceReliability = "HIGH" | "MEDIUM" | "LOW" | "UNASSESSED";

/** EvidenceResponse — GET /admin/evidences item. */
export interface Evidence {
  id: string;
  eventId: string;
  title: string;
  evidenceType: string;
  description: string | null;
  sourceTitle: string;
  sourceAuthor: string | null;
  sourceUrl: string | null;
  sourceCitation: string | null;
  sourcePublishedAt: string | null;
  reliability: EvidenceReliability | null;
  relevance: string | null;
  assetId: string | null;
  status: EvidenceStatus;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  rowVersion: number;
}

/** EvidenceUpsertRequest — POST /admin/evidences. */
export interface EvidenceUpsertRequest {
  eventId: string;
  title: string;
  evidenceType: string;
  description?: string;
  sourceTitle: string;
  sourceAuthor?: string;
  sourceUrl?: string;
  sourceCitation?: string;
  sourcePublishedAt?: string;
  reliability?: EvidenceReliability;
  relevance?: string;
  assetId?: string;
}

/** EvidencePatchRequest — PATCH /admin/evidences/{id}; absent=keep, null=clear. */
export type EvidencePatchRequest = Partial<Omit<EvidenceUpsertRequest, "eventId">>;

/** AssetResponse — GET /admin/assets item. `contentUrl` is a stable serving path. */
export interface AdminAsset {
  id: string;
  originalFilename: string | null;
  mimeType: string;
  sizeBytes: number;
  state: "UPLOADING" | "ACTIVE" | "RETIRED" | "FAILED";
  altText: string | null;
  createdAt: string;
  contentUrl: string;
}
