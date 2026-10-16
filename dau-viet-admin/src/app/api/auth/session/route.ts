import { NextResponse } from "next/server";

import type { TokenResponse } from "@/lib/dto/auth";
import { backendFetch } from "@/lib/server/backend";
import {
  buildRefreshCookie,
  clearRefreshCookie,
  readRefreshToken,
} from "@/lib/server/refresh-cookie";

/**
 * GET /api/auth/session — used by the admin layout to restore session after a
 * page reload. Rotates the refresh token, fetches /users/me, and returns
 * { user, accessToken, expiresIn }. The refresh token stays inside the cookie.
 */
export async function GET() {
  const refreshToken = await readRefreshToken();
  if (!refreshToken) {
    return NextResponse.json(
      { code: "UNAUTHORIZED", message: "Chưa đăng nhập" },
      { status: 401 },
    );
  }

  const refreshRes = await backendFetch("/api/v1/auth/refresh", {
    method: "POST",
    body: JSON.stringify({ refreshToken }),
  });
  const refreshText = await refreshRes.text();
  if (!refreshRes.ok) {
    const response = new NextResponse(refreshText, {
      status: refreshRes.status,
      headers: { "content-type": "application/json" },
    });
    response.headers.append("Set-Cookie", clearRefreshCookie());
    return response;
  }
  const tokens = JSON.parse(refreshText) as TokenResponse;

  const meRes = await backendFetch("/api/v1/users/me", {
    headers: { authorization: `Bearer ${tokens.accessToken}` },
  });
  const meText = await meRes.text();
  if (!meRes.ok) {
    const response = new NextResponse(meText, {
      status: meRes.status,
      headers: { "content-type": "application/json" },
    });
    response.headers.append(
      "Set-Cookie",
      buildRefreshCookie(tokens.refreshToken, tokens.refreshExpiresIn),
    );
    return response;
  }

  const response = new NextResponse(
    JSON.stringify({
      user: JSON.parse(meText),
      accessToken: tokens.accessToken,
      expiresIn: tokens.expiresIn,
    }),
    { status: 200, headers: { "content-type": "application/json" } },
  );
  response.headers.append(
    "Set-Cookie",
    buildRefreshCookie(tokens.refreshToken, tokens.refreshExpiresIn),
  );
  return response;
}
