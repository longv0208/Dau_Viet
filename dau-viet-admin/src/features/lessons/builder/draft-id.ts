/**
 * Slug-style id generator for draft stages/activities.
 * Backend ID_PATTERN: ^[a-z0-9][a-z0-9-]{1,63}$ — NOT UUIDs.
 */
const ID_PATTERN = /^[a-z0-9][a-z0-9-]{1,63}$/;
const ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789";

function randSlug(len: number): string {
  const buf = new Uint8Array(len);
  crypto.getRandomValues(buf);
  let out = "";
  for (const b of buf) out += ALPHABET[b % ALPHABET.length];
  return out;
}

/** Generate `<prefix>-<rand>` id matching backend pattern, unique within `existing`. */
export function genSlugId(prefix: string, existing: readonly string[]): string {
  const taken = new Set(existing);
  for (let i = 0; i < 20; i++) {
    const id = `${prefix}-${randSlug(6)}`;
    if (ID_PATTERN.test(id) && !taken.has(id)) return id;
  }
  // Deterministic fallback — practically unreachable.
  return `${prefix}-${Date.now().toString(36)}${randSlug(4)}`.slice(0, 64);
}

/** Item-level ids inside activity configs (options, pairs, markers…). */
export function genItemId(existing: readonly string[]): string {
  return genSlugId("it", existing);
}
