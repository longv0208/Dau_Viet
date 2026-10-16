import { z } from "zod";

/** A-01 login form — Vietnamese messages, matches backend LoginRequest. */
export const loginSchema = z.object({
  email: z
    .string()
    .min(1, "Vui lòng nhập email")
    .email("Email không hợp lệ"),
  password: z.string().min(1, "Vui lòng nhập mật khẩu"),
});

export type LoginFormValues = z.infer<typeof loginSchema>;

/**
 * ?next= allowlist: only known admin prefixes (no API/internal routes).
 * Rejects `//`, `\\`, schemes (javascript:, https:), query strings and
 * empty values → falls back to /dashboard.
 */
const ALLOWED_NEXT_PREFIXES = [
  "/dashboard",
  "/events",
  "/lessons",
  "/templates",
  "/assets",
  "/versions",
] as const;
const NEXT_PATH_RE = /^\/[a-zA-Z0-9\-_\/]*$/;

export function safeNext(raw: string | null | undefined): string {
  if (!raw) return "/dashboard";
  if (!NEXT_PATH_RE.test(raw)) return "/dashboard";
  if (raw.startsWith("//") || raw.includes("\\")) return "/dashboard";
  if (!ALLOWED_NEXT_PREFIXES.some((p) => raw === p || raw.startsWith(`${p}/`))) {
    return "/dashboard";
  }
  return raw;
}
