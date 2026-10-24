import { NextRequest, NextResponse } from "next/server";

import { env } from "@/env";

/** ~18 MB — bao multipart overhead quanh giới hạn backend 15 MB. */
const MAX_BODY = 18 * 1024 * 1024;

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
 * POST /api/upload/html-scene — multipart forwarder cho hoạt họa HTML
 * self-contained (backend chấp nhận ≤15 MB, lớn hơn cap JSON 2 MiB của
 * /api/proxy). Forward nguyên multipart lên POST
 * /api/v1/admin/animation-scenes/html-import kèm query title/eventId.
 * Auth: caller supplies `Authorization: Bearer <access>` — same as proxy.
 */
export async function POST(req: NextRequest) {
  const headers = new Headers();
  const auth = req.headers.get("authorization");
  if (!auth) {
    return NextResponse.json(
      { code: "UNAUTHORIZED", message: "Thiếu thông tin đăng nhập" },
      { status: 401 },
    );
  }
  headers.set("authorization", auth);
  const contentType = req.headers.get("content-type");
  if (!contentType || !contentType.toLowerCase().startsWith("multipart/form-data")) {
    return NextResponse.json(
      { code: "VALIDATION_ERROR", message: "Tệp tải lên không hợp lệ" },
      { status: 400 },
    );
  }
  headers.set("content-type", contentType);

  const buf = await req.arrayBuffer();
  if (buf.byteLength > MAX_BODY) {
    return NextResponse.json(
      { code: "PAYLOAD_TOO_LARGE", message: "Tệp HTML vượt quá 15 MB" },
      { status: 413 },
    );
  }

  const qs = req.nextUrl.search; // ?title=…&eventId=… — forward nguyên vẹn.
  let upstream: Response;
  try {
    upstream = await fetch(
      `${env.BACKEND_URL}/api/v1/admin/animation-scenes/html-import${qs}`,
      { method: "POST", headers, body: buf, cache: "no-store" },
    );
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
