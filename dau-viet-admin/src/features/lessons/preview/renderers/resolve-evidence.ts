import type { EmbeddedEvidence } from "./types";

/**
 * Resolves an evidence id against the embedded evidence[] documents.
 * Returns the record when present, null otherwise — callers must degrade
 * to a generic label rather than render the raw id as primary content.
 */
export function findEvidence(
  evidence: EmbeddedEvidence[] | undefined,
  id: string,
): EmbeddedEvidence | null {
  if (!evidence) return null;
  return evidence.find((e) => e.id === id) ?? null;
}

/** Short human label for an evidence chip: title → source title → fallback. */
export function evidenceLabel(
  evidence: EmbeddedEvidence[] | undefined,
  id: string,
  fallback: string,
): string {
  const doc = findEvidence(evidence, id);
  return doc?.title?.trim() || doc?.source?.title?.trim() || fallback;
}
