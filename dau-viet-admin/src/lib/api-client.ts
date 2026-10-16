import { ApiClientError } from "./api-error";
import { authStore } from "@/features/auth/auth-store";

/**
 * Client-side fetcher for the BFF proxy. Attaches the in-memory access token
 * and parses the ApiError envelope into a typed ApiClientError. On 401 it
 * single-flights one refresh, then retries the request once.
 */
let refreshInFlight: Promise<boolean> | null = null;

async function tryRefresh(): Promise<boolean> {
  if (!refreshInFlight) {
    refreshInFlight = (async () => {
      try {
        const res = await fetch("/api/auth/refresh", { method: "POST" });
        if (!res.ok) return false;
        const data = (await res.json()) as { accessToken: string; expiresIn: number };
        authStore.setAccessToken(data.accessToken, data.expiresIn);
        return true;
      } catch {
        return false;
      } finally {
        refreshInFlight = null;
      }
    })();
  }
  return refreshInFlight;
}

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
      const refreshed = await tryRefresh();
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
