import { cookies } from "next/headers";

/**
 * Refresh-token cookie helpers. The raw refresh token lives ONLY inside this
 * HttpOnly cookie — it is never serialized into a response body or exposed to
 * client JS. `Secure` is added in production (dev runs on plain http://localhost).
 */
export const REFRESH_COOKIE = "dv_refresh";
/**
 * Path must be "/" — middleware checks presence on every admin route, and the
 * (admin) layout calls /api/auth/session. Scoping to /api/auth would prevent
 * both from ever seeing the cookie. The token itself stays HttpOnly-only;
 * client JS can never read it regardless of path.
 */
const COOKIE_PATH = "/";

export function buildRefreshCookie(token: string, maxAgeSeconds: number): string {
  const parts = [
    `${REFRESH_COOKIE}=${token}`,
    "HttpOnly",
    `Path=${COOKIE_PATH}`,
    "SameSite=Lax",
    `Max-Age=${maxAgeSeconds}`,
  ];
  if (process.env.NODE_ENV === "production") parts.push("Secure");
  return parts.join("; ");
}

export function clearRefreshCookie(): string {
  const parts = [
    `${REFRESH_COOKIE}=`,
    "HttpOnly",
    `Path=${COOKIE_PATH}`,
    "SameSite=Lax",
    "Max-Age=0",
  ];
  if (process.env.NODE_ENV === "production") parts.push("Secure");
  return parts.join("; ");
}

export async function readRefreshToken(): Promise<string | null> {
  const jar = await cookies();
  return jar.get(REFRESH_COOKIE)?.value ?? null;
}
