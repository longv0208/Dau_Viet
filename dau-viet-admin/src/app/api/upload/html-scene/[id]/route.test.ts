import { describe, expect, it, vi, beforeEach } from "vitest";
import type { NextRequest } from "next/server";

import { PUT } from "./route";

const BACKEND = "http://localhost:8080";
const CTX = { params: Promise.resolve({ id: "scene-1" }) };

function makeReq(body: BodyInit | null, headers: Record<string, string> = {}) {
  const url =
    "http://localhost/api/upload/html-scene/scene-1?expectedRowVersion=3";
  const r = new Request(url, {
    method: "PUT",
    headers: { authorization: "Bearer tok", ...headers },
    body,
  });
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

describe("PUT /api/upload/html-scene/[id]", () => {
  it("401 khi thiếu Authorization", async () => {
    const r = await PUT(makeReq(null, { authorization: "" }), CTX);
    expect(r.status).toBe(401);
  });

  it("400 khi không phải multipart", async () => {
    const r = await PUT(makeReq("{}", { "content-type": "application/json" }), CTX);
    expect(r.status).toBe(400);
  });

  it("forward PUT tới /{id}/html-draft kèm expectedRowVersion", async () => {
    const { body, contentType } = multipartBody(2 * 1024 * 1024);
    const spy = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(new Response('{"id":"scene-1"}', { status: 200 }));
    const r = await PUT(makeReq(body, { "content-type": contentType }), CTX);
    expect(r.status).toBe(200);
    const url = spy.mock.calls[0]?.[0] as string;
    expect(url).toBe(
      `${BACKEND}/api/v1/admin/animation-scenes/scene-1/html-draft?expectedRowVersion=3`,
    );
    const sent = spy.mock.calls[0]?.[1] as RequestInit;
    expect(sent.method).toBe("PUT");
  });

  it(">18MB → 413", async () => {
    const { body, contentType } = multipartBody(19 * 1024 * 1024);
    const spy = vi.spyOn(globalThis, "fetch");
    const r = await PUT(makeReq(body, { "content-type": contentType }), CTX);
    expect(r.status).toBe(413);
    expect(spy).not.toHaveBeenCalled();
  });
});
