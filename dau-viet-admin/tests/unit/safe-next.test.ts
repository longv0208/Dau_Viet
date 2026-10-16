import { describe, expect, it } from "vitest";

import { safeNext } from "@/features/auth/schemas";

describe("safeNext — open-redirect guard", () => {
  it("returns /dashboard for null/empty input", () => {
    expect(safeNext(null)).toBe("/dashboard");
    expect(safeNext(undefined)).toBe("/dashboard");
    expect(safeNext("")).toBe("/dashboard");
  });

  it("accepts same-origin absolute paths", () => {
    expect(safeNext("/dashboard")).toBe("/dashboard");
    expect(safeNext("/events/abc-123")).toBe("/events/abc-123");
    expect(safeNext("/lessons")).toBe("/lessons");
  });

  it("rejects protocol-relative URLs", () => {
    expect(safeNext("//evil.com")).toBe("/dashboard");
    expect(safeNext("//evil.com/path")).toBe("/dashboard");
  });

  it("rejects backslash variants", () => {
    expect(safeNext("\\\\evil.com")).toBe("/dashboard");
    expect(safeNext("/\\evil")).toBe("/dashboard");
  });

  it("rejects absolute URLs with schemes", () => {
    expect(safeNext("https://evil.com")).toBe("/dashboard");
    expect(safeNext("javascript:alert(1)")).toBe("/dashboard");
    expect(safeNext("http://localhost:3000/x")).toBe("/dashboard");
  });

  it("rejects paths with disallowed characters", () => {
    expect(safeNext("/events?x=1")).toBe("/dashboard"); // '?' not in allowlist
    expect(safeNext("/events#frag")).toBe("/dashboard");
    expect(safeNext("/events/foo bar")).toBe("/dashboard");
  });
});
