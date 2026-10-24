/**
 * Safe "?return=" handling for workspace-context navigation.
 *
 * Only whitelisted internal paths (a known admin section + optional query)
 * are accepted — anything else (external URL, `//`, `javascript:`,
 * malformed UUID, unknown section) is rejected and callers fall back to a
 * default destination. Never render a raw `?return=` value into a `Link
 * href` without passing it through `parseReturnTo` first.
 */

const RETURN_PATH =
  /^\/(events|lessons|evidence|animations|versions|templates|assets)\/[0-9a-fA-F-]{36}(\?[a-zA-Z0-9=&%_-]*)?$/;

/** `/lessons/new[?event=<uuid>&…]` — the create-lesson wizard is a valid
 * return target (template authoring sends the admin back to step 2). */
const RETURN_LESSONS_NEW =
  /^\/lessons\/new(\?[a-zA-Z0-9=&%_-]*)?$/;

/**
 * Validate a raw `?return=` value → the path if it is a whitelisted
 * internal admin URL, else `null`.
 */
export function parseReturnTo(raw: string | null | undefined): string | null {
  if (!raw) return null;
  // Reject anything that isn't a single relative path.
  if (raw.startsWith("//") || raw.includes("://") || raw.includes("..")) {
    return null;
  }
  return RETURN_PATH.test(raw) || RETURN_LESSONS_NEW.test(raw) ? raw : null;
}

/**
 * Append `?return=` (or `&return=` when `href` already has a query) to an
 * internal link. `returnTo` must already have passed `parseReturnTo`; a
 * `null` returnTo leaves the href unchanged.
 */
export function withReturnTo(href: string, returnTo: string | null): string {
  if (!returnTo) return href;
  const sep = href.includes("?") ? "&" : "?";
  return `${href}${sep}return=${encodeURIComponent(returnTo)}`;
}
