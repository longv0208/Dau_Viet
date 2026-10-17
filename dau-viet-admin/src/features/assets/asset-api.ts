import { ApiClientError } from "@/lib/api-error";
import { authStore } from "@/features/auth/auth-store";
import { coordinatedRefresh } from "@/features/auth/refresh-coordinator";
import type { AdminAsset } from "@/lib/dto/evidence";

/**
 * Multipart upload — bypasses apiFetch because the request body is FormData
 * (the proxy forwards content-type verbatim; apiFetch would force JSON).
 * Same auth + single-flight refresh behaviour as apiFetch.
 */
export async function uploadAsset(file: File, altText?: string): Promise<AdminAsset> {
  const doUpload = async (): Promise<AdminAsset> => {
    const token = authStore.getAccessToken();
    const fd = new FormData();
    fd.append("file", file);
    if (altText && altText.trim()) fd.append("altText", altText.trim());
    const res = await fetch("/api/proxy/admin/assets", {
      method: "POST",
      headers: token ? { authorization: `Bearer ${token}` } : undefined,
      body: fd,
    });
    const body = await res.json().catch(() => null);
    if (!res.ok) throw ApiClientError.from(body, res.status);
    return body as AdminAsset;
  };
  try {
    return await doUpload();
  } catch (err) {
    if (err instanceof ApiClientError && err.isUnauthorized) {
      const refreshed = await coordinatedRefresh();
      if (refreshed) return doUpload();
      authStore.clear();
      if (typeof window !== "undefined") window.location.assign("/login");
    }
    throw err;
  }
}

/** contentUrl comes back as `/api/v1/admin/assets/{id}/content` — the browser
 * path goes through the BFF proxy, which prepends /api/v1 itself. */
export function assetContentSrc(contentUrl: string): string {
  const stripped = contentUrl.replace(/^\/api\/v1/, "");
  return `/api/proxy${stripped}`;
}
