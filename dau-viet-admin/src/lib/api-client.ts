import { ApiClientError } from "./api-error";
import { authStore } from "@/features/auth/auth-store";
import { coordinatedRefresh } from "@/features/auth/refresh-coordinator";

/**
 * Client-side fetcher for the BFF proxy. Attaches the in-memory access token
 * and parses the ApiError envelope into a typed ApiClientError. On 401 it
 * single-flights one refresh (via coordinatedRefresh — shared with the
 * session bootstrap, so bootstrap and a query can't rotate twice), then
 * retries the request once.
 */

async function rawFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const token = authStore.getAccessToken();
  const res = await fetch(`/api/proxy${path}`, {
    ...init,
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...init?.headers,
    },
  });
  if (res.status === 204) return undefined as T;
  const body = await res.json().catch(() => null);
  if (!res.ok) throw ApiClientError.from(body, res.status);
  return body as T;
}

export async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  try {
    return await rawFetch<T>(path, init);
  } catch (err) {
    if (err instanceof ApiClientError && err.isUnauthorized) {
      const refreshed = await coordinatedRefresh();
      if (refreshed) return rawFetch<T>(path, init);
      authStore.clear();
      if (typeof window !== "undefined") window.location.assign("/login");
    }
    throw err;
  }
}

/** Serialize query params, skipping null/undefined/empty. */
export function toQuery(params: Record<string, string | number | undefined | null>): string {
  const sp = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null && v !== "") sp.set(k, String(v));
  }
  const s = sp.toString();
  return s ? `?${s}` : "";
}
