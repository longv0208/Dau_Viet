import { NextResponse } from "next/server";

import { backendFetch } from "@/lib/server/backend";
import { clearRefreshCookie, readRefreshToken } from "@/lib/server/refresh-cookie";

/**
 * POST /api/auth/logout — revokes the refresh token server-side (when
 * present) and always clears the cookie. Idempotent by design.
 */
export async function POST() {
  const refreshToken = await readRefreshToken();
  if (refreshToken) {
    try {
      await backendFetch("/api/v1/auth/logout", {
        method: "POST",
        body: JSON.stringify({ refreshToken }),
      });
    } catch {
      // Backend unreachable — still clear the cookie so the user is signed out locally.
    }
  }
  const response = new NextResponse(null, { status: 204 });
  response.headers.append("Set-Cookie", clearRefreshCookie());
  return response;
}
