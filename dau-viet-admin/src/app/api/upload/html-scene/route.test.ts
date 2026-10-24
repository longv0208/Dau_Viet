import { describe, expect, it, vi, beforeEach } from "vitest";
import type { NextRequest } from "next/server";

import { POST } from "./route";

/**
 * Unit cho BFF HTML import route — khác assets: cap 18MB, forward query
 * (title/eventId) nguyên vẹn, upstream là /html-import.
 */

const BACKEND = "http://localhost:8080";

function makeReq(body: BodyInit | null, headers: Record<string, string> = {}) {
  const url = "http://localhost/api/upload/html-scene?title=T&eventId=e1";
  const r = new Request(url, {
    method: "POST",
    headers: { authorization: "Bearer tok", ...headers },
    body,
  });
  // Route đọc req.nextUrl.search — Request gốc không có; gắn URL-shaped.
  (r as unknown as { nextUrl: URL }).nextUrl = new URL(url);
  return r as unknown as NextRequest;
}

function multipartBody(bytes: number): { body: ArrayBuffer; contentType: string } {
  const boundary = "----vitest";
  const head =
    `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="file"; filename="scene.html"\r\n` +
    `Content-Type: text/html\r\n\r\n`;
  const tail = `\r\n--${boundary}--\r\n`;
  const payload = new Uint8Array(bytes).fill(0x3c);
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

describe("POST /api/upload/html-scene", () => {
  it("401 khi thiếu Authorization", async () => {
    const r = await POST(makeReq(null, { authorization: "" }));
    expect(r.status).toBe(401);
  });

  it("400 khi không phải multipart/form-data", async () => {
    const r = await POST(makeReq("{}", { "content-type": "application/json" }));
    expect(r.status).toBe(400);
  });

  it("forward multipart + query title/eventId tới /html-import", async () => {
    const { body, contentType } = multipartBody(3 * 1024 * 1024); // 3MB > proxy 2MiB
    const spy = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(new Response('{"id":"s1"}', { status: 201 }));
    const r = await POST(makeReq(body, { "content-type": contentType }));
    expect(r.status).toBe(201);
    const url = spy.mock.calls[0]?.[0] as string;
    expect(url).toBe(
      `${BACKEND}/api/v1/admin/animation-scenes/html-import?title=T&eventId=e1`,
    );
    const sent = spy.mock.calls[0]?.[1] as RequestInit;
    expect((sent.headers as Headers).get("authorization")).toBe("Bearer tok");
    expect(sent.method).toBe("POST");
  });

  it(">18MB → 413 trước khi gọi backend", async () => {
    const { body, contentType } = multipartBody(19 * 1024 * 1024);
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

  it("422 validation errors pass-through nguyên envelope", async () => {
    const upstream = new Response(
      '{"code":"ANIMATION_HTML_INVALID","message":"bad","details":{"errors":[{"path":"html","code":"EXTERNAL_REF","message":"Dòng 3: fetch()"}]}}',
      { status: 422, headers: { "content-type": "application/json" } },
    );
    vi.spyOn(globalThis, "fetch").mockResolvedValue(upstream);
    const { body, contentType } = multipartBody(64);
    const r = await POST(makeReq(body, { "content-type": contentType }));
    expect(r.status).toBe(422);
    const body2 = (await r.json()) as { code: string };
    expect(body2.code).toBe("ANIMATION_HTML_INVALID");
  });
});
