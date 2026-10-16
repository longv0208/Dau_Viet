import { createHash } from "node:crypto";

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
 *
 * Concurrency: the backend treats a replayed (already-revoked) refresh token
 * as theft and revokes the whole family — two tabs or a StrictMode double
 * effect presenting the SAME cookie would double-rotate and force a logout.
 * A module-level map keyed by the presented token's SHA-256 dedups those
 * simultaneous calls: the second request awaits the first's upstream
 * response and gets its own Set-Cookie for the same rotated token. The map
 * lives only for the lifetime of a single request per key; tokens never
 * persist beyond it.
 */

interface Rotation {
  status: number;
  body: string;
  nextRefreshToken?: string;
  nextRefreshExpiresIn?: number;
}

const inflight = new Map<string, Promise<Rotation>>();

function keyFor(refreshToken: string): string {
  return createHash("sha256").update(refreshToken).digest("hex");
}

async function rotate(refreshToken: string): Promise<Rotation> {
  const res = await backendFetch("/api/v1/auth/refresh", {
    method: "POST",
    body: JSON.stringify({ refreshToken }),
  });
  const body = await res.text();
  if (!res.ok) return { status: res.status, body };

  const tokens = JSON.parse(body) as TokenResponse;
  return {
    status: res.status,
    body: JSON.stringify({
      accessToken: tokens.accessToken,
      expiresIn: tokens.expiresIn,
    }),
    nextRefreshToken: tokens.refreshToken,
    nextRefreshExpiresIn: tokens.refreshExpiresIn,
  };
}

export async function POST() {
  const refreshToken = await readRefreshToken();
  if (!refreshToken) {
    return NextResponse.json(
      { code: "UNAUTHORIZED", message: "Chưa đăng nhập" },
      { status: 401 },
    );
  }

  const key = keyFor(refreshToken);
  let pending = inflight.get(key);
  if (!pending) {
    pending = rotate(refreshToken).finally(() => {
      inflight.delete(key);
    });
    inflight.set(key, pending);
  }
  const rotation = await pending;

  if (rotation.status !== 200) {
    const response = new NextResponse(rotation.body, {
      status: rotation.status,
      headers: { "content-type": "application/json" },
    });
    response.headers.append("Set-Cookie", clearRefreshCookie());
    return response;
  }

  const response = new NextResponse(rotation.body, {
    status: 200,
    headers: { "content-type": "application/json" },
  });
  response.headers.append(
    "Set-Cookie",
    buildRefreshCookie(
      rotation.nextRefreshToken as string,
      rotation.nextRefreshExpiresIn as number,
    ),
  );
  return response;
}
