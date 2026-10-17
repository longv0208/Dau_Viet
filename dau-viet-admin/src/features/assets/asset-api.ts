import { ApiClientError } from "@/lib/api-error";
import { authStore } from "@/features/auth/auth-store";
import { coordinatedRefresh } from "@/features/auth/refresh-coordinator";
import type { AdminAsset } from "@/lib/dto/evidence";

/** Giới hạn backend — PNG/JPEG/WebP ≤10 MB. */
export const MAX_ASSET_BYTES = 10 * 1024 * 1024;
const ALLOWED_TYPES = new Set(["image/png", "image/jpeg", "image/webp"]);

/** Client-side guard trước khi upload; trả chuỗi lỗi VN hoặc null. Backend vẫn authoritative. */
export function validateAssetFile(file: File): string | null {
  if (!ALLOWED_TYPES.has(file.type)) {
    return "Định dạng không hỗ trợ — chỉ nhận PNG, JPEG hoặc WebP.";
  }
  if (file.size > MAX_ASSET_BYTES) {
    return `Ảnh vượt quá ${MAX_ASSET_BYTES / (1024 * 1024)} MB (${(file.size / (1024 * 1024)).toFixed(1)} MB).`;
  }
  if (file.size === 0) return "Tệp rỗng — chọn ảnh khác.";
  return null;
}

/** Đường upload chuyên multipart — không qua proxy JSON (cap 2 MiB). */
const UPLOAD_PATH = "/api/upload/assets";

/**
 * Multipart upload — dùng route riêng /api/upload/assets (cap ~12MB) thay vì
 * proxy JSON 2 MiB. Same auth + single-flight refresh behaviour as apiFetch.
 */
export async function uploadAsset(file: File, altText?: string): Promise<AdminAsset> {
  const doUpload = async (): Promise<AdminAsset> => {
    const token = authStore.getAccessToken();
    const fd = new FormData();
    fd.append("file", file);
    if (altText && altText.trim()) fd.append("altText", altText.trim());
    const res = await fetch(UPLOAD_PATH, {
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

/** Fetch asset bytes as a Blob through the BFF proxy (auth + refresh). */
export async function fetchAssetBlob(contentUrl: string): Promise<Blob> {
  const stripped = contentUrl.replace(/^\/api\/v1/, "");
  const doFetch = async (): Promise<Blob> => {
    const token = authStore.getAccessToken();
    const res = await fetch(`/api/proxy${stripped}`, {
      headers: token ? { authorization: `Bearer ${token}` } : undefined,
    });
    if (!res.ok) {
      const body = await res.json().catch(() => null);
      throw ApiClientError.from(body, res.status);
    }
    return res.blob();
  };
  try {
    return await doFetch();
  } catch (err) {
    if (err instanceof ApiClientError && err.isUnauthorized) {
      const refreshed = await coordinatedRefresh();
      if (refreshed) return doFetch();
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
