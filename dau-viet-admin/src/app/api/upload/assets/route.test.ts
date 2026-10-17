import { describe, expect, it, vi, beforeEach } from "vitest";
import type { NextRequest } from "next/server";

import { POST } from "./route";

/**
 * Unit cho BFF multipart upload route — verify >2MiB pass (khác proxy JSON),
 * >12MB → 413, non-multipart → 400, thiếu auth → 401, upstream fail → 502,
 * và hop-by-hop/set-cookie bị strip khỏi response.
 *
 * Route chỉ đọc `req.headers` + `req.arrayBuffer()` nên dùng Request gốc và
 * cast sang NextRequest — tránh NextRequest phải parse multipart trong jsdom.
 */

const BACKEND = "http://localhost:8080";

function makeReq(body: BodyInit | null, headers: Record<string, string> = {}) {
  const r = new Request("http://localhost/api/upload/assets", {
    method: "POST",
    headers: { authorization: "Bearer tok", ...headers },
    body,
  });
  return r as unknown as NextRequest;
}

function multipartBody(bytes: number): { body: ArrayBuffer; contentType: string } {
  const boundary = "----vitest";
  const head =
    `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="file"; filename="a.png"\r\n` +
    `Content-Type: image/png\r\n\r\n`;
  const tail = `\r\n--${boundary}--\r\n`;
  const payload = new Uint8Array(bytes).fill(0x89);
  const buf = new Uint8Array(head.length + payload.length + tail.length);
  buf.set(new TextEncoder().encode(head), 0);
  buf.set(payload, head.length);
  buf.set(new TextEncoder().encode(tail), head.length + payload.length);
  return {
    body: buf.buffer,
    contentType: `multipart/form-data; boundary=${boundary}`,
  };
}

beforeEach(() => {
  vi.restoreAllMocks();
});

describe("POST /api/upload/assets", () => {
  it("401 khi thiếu Authorization", async () => {
    const r = await POST(makeReq(null, { authorization: "" }));
    expect(r.status).toBe(401);
  });

  it("400 khi không phải multipart/form-data", async () => {
    const r = await POST(makeReq("{}", { "content-type": "application/json" }));
    expect(r.status).toBe(400);
  });

  it("forward multipart 3–5MB tới backend (>2MiB proxy cap)", async () => {
    const { body, contentType } = multipartBody(3 * 1024 * 1024); // 3 MB
    const spy = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(new Response('{"id":"a1"}', { status: 201 }));
    const r = await POST(makeReq(body, { "content-type": contentType }));
    expect(r.status).toBe(201);
    expect(spy).toHaveBeenCalledWith(
      `${BACKEND}/api/v1/admin/assets`,
      expect.objectContaining({ method: "POST" }),
    );
    const sent = spy.mock.calls[0]?.[1] as RequestInit;
    expect((sent.headers as Headers).get("authorization")).toBe("Bearer tok");
    expect((sent.body as ArrayBuffer).byteLength).toBeGreaterThan(2 * 1024 * 1024);
  });

  it(">12MB → 413 trước khi gọi backend", async () => {
    const { body, contentType } = multipartBody(13 * 1024 * 1024);
    const spy = vi.spyOn(globalThis, "fetch");
    const r = await POST(makeReq(body, { "content-type": contentType }));
    expect(r.status).toBe(413);
    expect(spy).not.toHaveBeenCalled();
  });

  it("upstream fail → 502", async () => {
    vi.spyOn(globalThis, "fetch").mockRejectedValue(new Error("down"));
    const { body, contentType } = multipartBody(64);
    const r = await POST(makeReq(body, { "content-type": contentType }));
    expect(r.status).toBe(502);
  });

  it("strip set-cookie + hop-by-hop khỏi response", async () => {
    const upstream = new Response("{}", {
      status: 201,
      headers: {
        "set-cookie": "dv_refresh=xxx; HttpOnly",
        "transfer-encoding": "chunked",
        "content-type": "application/json",
      },
    });
    vi.spyOn(globalThis, "fetch").mockResolvedValue(upstream);
    const { body, contentType } = multipartBody(64);
    const r = await POST(makeReq(body, { "content-type": contentType }));
    expect(r.status).toBe(201);
    expect(r.headers.get("set-cookie")).toBeNull();
    expect(r.headers.get("transfer-encoding")).toBeNull();
    expect(r.headers.get("content-type")).toBe("application/json");
  });
});
