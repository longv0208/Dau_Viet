/**
 * Shared form helpers for admin authoring screens.
 * - toSlug: Vietnamese-aware kebab-case suggestion (matches backend slug regex).
 * - fieldErrors: map a VALIDATION_ERROR ApiClientError.details {field: msg}
 *   onto react-hook-form setError calls.
 */

import type { UseFormSetError, FieldValues, Path } from "react-hook-form";

import { ApiClientError } from "./api-error";

/** Vietnamese diacritics → ASCII for slug suggestion. */
const VI_MAP: Record<string, string> = {
  à: "a", á: "a", ả: "a", ã: "a", ạ: "a",
  ă: "a", ằ: "a", ắ: "a", ẳ: "a", ẵ: "a", ặ: "a",
  â: "a", ầ: "a", ấ: "a", ẩ: "a", ẫ: "a", ậ: "a",
  đ: "d",
  è: "e", é: "e", ẻ: "e", ẽ: "e", ẹ: "e",
  ê: "e", ề: "e", ế: "e", ể: "e", ễ: "e", ệ: "e",
  ì: "i", í: "i", ỉ: "i", ĩ: "i", ị: "i",
  ò: "o", ó: "o", ỏ: "o", õ: "o", ọ: "o",
  ô: "o", ồ: "o", ố: "o", ổ: "o", ỗ: "o", ộ: "o",
  ơ: "o", ờ: "o", ớ: "o", ở: "o", ỡ: "o", ợ: "o",
  ù: "u", ú: "u", ủ: "u", ũ: "u", ụ: "u",
  ư: "u", ừ: "u", ứ: "u", ử: "u", ữ: "u", ự: "u",
  ỳ: "y", ý: "y", ỷ: "y", ỹ: "y", ỵ: "y",
};

/** Suggest a backend-valid slug: lowercase kebab-case, ASCII-only. */
export function toSlug(input: string): string {
  return input
    .toLowerCase()
    .split("")
    .map((c) => VI_MAP[c] ?? c)
    .join("")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .replace(/-{2,}/g, "-")
    .slice(0, 150);
}

/**
 * Push backend `details {field: msg}` onto matching RHF fields. Returns true
 * when at least one field was mapped; unmapped fields fall back to the
 * generic error toast.
 */
export function applyServerFieldErrors<T extends FieldValues>(
  err: unknown,
  setError: UseFormSetError<T>,
  fields: readonly Path<T>[],
): boolean {
  if (!(err instanceof ApiClientError) || !err.isValidation) return false;
  let mapped = false;
  for (const f of fields) {
    const msg = err.details?.[f as string];
    if (typeof msg === "string") {
      setError(f, { type: "server", message: msg });
      mapped = true;
    }
  }
  return mapped;
}
