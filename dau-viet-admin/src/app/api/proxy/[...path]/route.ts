import { NextRequest, NextResponse } from "next/server";

import { env } from "@/env";

const HOP_BY_HOP = new Set([
  "connection",
  "keep-alive",
  "transfer-encoding",
  "te",
  "trailer",
  "upgrade",
  "host",
  "content-length",
]);

/**
 * ALL /api/proxy/<path> — thin forwarder to the backend. The client supplies
 * `Authorization: Bearer <access>` (access token lives only in browser memory);
 * the refresh-token cookie is never forwarded. Single origin keeps future
 * CSRF/cookie work simple.
 */
async function forward(req: NextRequest, path: string[]): Promise<Response> {
  const upstreamPath = `/api/v1/${path.join("/")}`;
  const url = `${env.BACKEND_URL}${upstreamPath}${req.nextUrl.search}`;

  const headers = new Headers();
  const auth = req.headers.get("authorization");
  if (auth) headers.set("authorization", auth);
  const contentType = req.headers.get("content-type");
  if (contentType) headers.set("content-type", contentType);

  let body: BodyInit | undefined;
  if (req.method !== "GET" && req.method !== "HEAD") {
    // Cap proxied bodies at 2 MiB — admin mutations are JSON; media upload
    // will go through a dedicated route with its own limit when it lands.
    const buf = await req.arrayBuffer();
    if (buf.byteLength > 2 * 1024 * 1024) {
      return NextResponse.json(
        { code: "PAYLOAD_TOO_LARGE", message: "Nội dung quá lớn — hãy rút ngắn văn bản hoặc bớt nội dung" },
        { status: 413 },
      );
    }
    body = buf;
  }

  let upstream: Response;
  try {
    upstream = await fetch(url, { method: req.method, headers, body, cache: "no-store" });
  } catch {
    return NextResponse.json(
      { code: "UPSTREAM_UNAVAILABLE", message: "Không kết nối được máy chủ" },
      { status: 502 },
    );
  }

  const outHeaders = new Headers();
  upstream.headers.forEach((value, key) => {
    if (!HOP_BY_HOP.has(key.toLowerCase()) && key.toLowerCase() !== "set-cookie") {
      outHeaders.set(key, value);
    }
  });
  return new NextResponse(upstream.body, { status: upstream.status, headers: outHeaders });
}

type Ctx = { params: Promise<{ path: string[] }> };

export async function GET(req: NextRequest, ctx: Ctx) {
  return forward(req, (await ctx.params).path);
}
export async function POST(req: NextRequest, ctx: Ctx) {
  return forward(req, (await ctx.params).path);
}
export async function PUT(req: NextRequest, ctx: Ctx) {
  return forward(req, (await ctx.params).path);
}
export async function PATCH(req: NextRequest, ctx: Ctx) {
  return forward(req, (await ctx.params).path);
}
export async function DELETE(req: NextRequest, ctx: Ctx) {
  return forward(req, (await ctx.params).path);
}
