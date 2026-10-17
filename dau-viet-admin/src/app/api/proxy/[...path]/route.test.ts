import { describe, expect, it, vi, beforeEach } from "vitest";
import type { NextRequest } from "next/server";

import { POST } from "./route";

/** Proxy JSON giữ nguyên cap 2 MiB — multipart lớn phải đi /api/upload/assets. */

const BACKEND = "http://localhost:8080";
const ctx = { params: Promise.resolve({ path: ["admin", "events"] }) };

function makeReq(body: BodyInit | null, headers: Record<string, string> = {}) {
  const r = new Request("http://localhost/api/proxy/admin/events", {
    method: "POST",
    headers: { authorization: "Bearer tok", ...headers },
    body,
  });
  // Route đọc `req.nextUrl.search` — gắn NextUrl-like tối thiểu.
  (r as unknown as { nextUrl: URL }).nextUrl = new URL(r.url);
  return r as unknown as NextRequest;
}

beforeEach(() => {
  vi.restoreAllMocks();
});

describe("POST /api/proxy/* — JSON cap", () => {
  it("body >2MiB → 413 trước khi gọi backend", async () => {
    const big = new Uint8Array(2 * 1024 * 1024 + 1);
    const spy = vi.spyOn(globalThis, "fetch");
    const r = await POST(makeReq(big, { "content-type": "application/json" }), ctx);
    expect(r.status).toBe(413);
    expect(spy).not.toHaveBeenCalled();
  });

  it("body ≤2MiB được forward", async () => {
    const ok = JSON.stringify({ a: "x".repeat(100) });
    const spy = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(new Response('{"ok":true}', { status: 200 }));
    const r = await POST(makeReq(ok, { "content-type": "application/json" }), ctx);
    expect(r.status).toBe(200);
    expect(spy).toHaveBeenCalledWith(
      `${BACKEND}/api/v1/admin/events`,
      expect.objectContaining({ method: "POST" }),
    );
  });
});
