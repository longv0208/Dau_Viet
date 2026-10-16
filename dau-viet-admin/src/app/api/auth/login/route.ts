import { NextResponse } from "next/server";

import type { TokenResponse } from "@/lib/dto/auth";
import { backendFetch } from "@/lib/server/backend";
import { buildRefreshCookie } from "@/lib/server/refresh-cookie";

/**
 * POST /api/auth/login — BFF login. Calls the backend, stores the refresh
 * token in an HttpOnly cookie, and returns only { accessToken, expiresIn }
 * to the browser. The raw refreshToken never reaches client JS.
 */
export async function POST(req: Request) {
  let body: { email?: string; password?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json(
      { code: "VALIDATION_ERROR", message: "Yêu cầu không hợp lệ" },
      { status: 400 },
    );
  }
  if (!body.email || !body.password) {
    return NextResponse.json(
      { code: "VALIDATION_ERROR", message: "Vui lòng nhập email và mật khẩu" },
      { status: 400 },
    );
  }

  const res = await backendFetch("/api/v1/auth/login", {
    method: "POST",
    body: JSON.stringify({ email: body.email, password: body.password }),
  });

  const text = await res.text();
  if (!res.ok) {
    return new NextResponse(text, {
      status: res.status,
      headers: { "content-type": "application/json" },
    });
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
