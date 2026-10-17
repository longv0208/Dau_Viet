import { NextRequest, NextResponse } from "next/server";

import { env } from "@/env";

/** ~12 MB — bao multipart overhead quanh giới hạn backend 10 MB. */
const MAX_BODY = 12 * 1024 * 1024;

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
 * POST /api/upload/assets — dedicated multipart forwarder.
 * The general /api/proxy JSON cap stays at 2 MiB; image uploads (backend
 * accepts ≤10 MB) come here instead so the advertised limit is honest.
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
      { code: "VALIDATION_ERROR", message: "Yêu cầu phải là multipart/form-data" },
      { status: 400 },
    );
  }
  headers.set("content-type", contentType);

  const buf = await req.arrayBuffer();
  if (buf.byteLength > MAX_BODY) {
    return NextResponse.json(
      { code: "PAYLOAD_TOO_LARGE", message: "Ảnh vượt quá 10 MB" },
      { status: 413 },
    );
  }

  let upstream: Response;
  try {
    upstream = await fetch(`${env.BACKEND_URL}/api/v1/admin/assets`, {
      method: "POST",
      headers,
      body: buf,
      cache: "no-store",
    });
  } catch {
    return NextResponse.json(
      { code: "UPSTREAM_UNAVAILABLE", message: "Không thể kết nối máy chủ backend" },
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
