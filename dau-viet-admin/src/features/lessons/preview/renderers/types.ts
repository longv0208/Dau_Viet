import type { Activity } from "../../builder/draft-model";

/**
 * Embedded evidence document — denormalized copy inside the snapshot/draft
 * projection. Renderers resolve ids to these records; never fetch by id.
 */
export interface EmbeddedEvidence {
  id: string;
  title?: string;
  evidenceType?: string;
  description?: string;
  source?: {
    title?: string;
    author?: string;
    url?: string;
    citation?: string;
    publishedAt?: string;
  };
  reliability?: string;
  relevance?: string;
  assetId?: string;
}

/** Embedded asset document — storageKey/mime for image resolution. */
export interface EmbeddedAsset {
  id: string;
  storageKey?: string;
  mimeType?: string;
  originalFilename?: string;
  altText?: string;
}

/** Props every preview renderer receives — activity is the projection node. */
export interface PreviewActivityProps {
  activity: Activity;
  /**
   * Denormalized evidence/assets embedded in the lesson content — present on
   * preview responses that went through the snapshot pipeline. Renderers fall
   * back to id-only labels when a referenced id has no matching record.
   */
  evidence?: EmbeddedEvidence[];
  assets?: EmbeddedAsset[];
}
