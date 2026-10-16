import { NextResponse } from "next/server";

import type { TokenResponse } from "@/lib/dto/auth";
import { backendFetch } from "@/lib/server/backend";
import {
  buildRefreshCookie,
  clearRefreshCookie,
  readRefreshToken,
} from "@/lib/server/refresh-cookie";

/**
 * POST /api/auth/refresh — rotates the refresh token via the backend
 * (backend revokes the old token), re-sets the HttpOnly cookie, and returns
 * a fresh { accessToken, expiresIn }. On upstream 400/401 the cookie is
 * cleared so the client falls back to login.
 */
export async function POST() {
  const refreshToken = await readRefreshToken();
  if (!refreshToken) {
    return NextResponse.json(
      { code: "UNAUTHORIZED", message: "Chưa đăng nhập" },
      { status: 401 },
    );
  }

  const res = await backendFetch("/api/v1/auth/refresh", {
    method: "POST",
    body: JSON.stringify({ refreshToken }),
  });
  const text = await res.text();

  if (!res.ok) {
    const response = new NextResponse(text, {
      status: res.status,
      headers: { "content-type": "application/json" },
    });
    response.headers.append("Set-Cookie", clearRefreshCookie());
    return response;
  }

  const tokens = JSON.parse(text) as TokenResponse;
  const response = NextResponse.json({
    accessToken: tokens.accessToken,
    expiresIn: tokens.expiresIn,
  });
  response.headers.append(
    "Set-Cookie",
    buildRefreshCookie(tokens.refreshToken, tokens.refreshExpiresIn),
  );
  return response;
}
