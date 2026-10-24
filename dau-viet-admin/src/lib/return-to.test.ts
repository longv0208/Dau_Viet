import { describe, expect, it } from "vitest";

import { parseReturnTo, withReturnTo } from "./return-to";

const VALID_UUID = "11111111-1111-1111-1111-111111111111";

describe("parseReturnTo", () => {
  it("accepts a whitelisted event workspace path", () => {
    expect(parseReturnTo(`/events/${VALID_UUID}`)).toBe(`/events/${VALID_UUID}`);
  });

  it("accepts a whitelisted path with a safe query string", () => {
    const raw = `/events/${VALID_UUID}?tab=hoc-lieu`;
    expect(parseReturnTo(raw)).toBe(raw);
  });

  it("accepts lessons/evidence/animations/versions/templates/assets sections", () => {
    for (const section of ["lessons", "evidence", "animations", "versions", "templates", "assets"]) {
      expect(parseReturnTo(`/${section}/${VALID_UUID}`)).toBe(`/${section}/${VALID_UUID}`);
    }
  });

  it("rejects null, undefined and empty input", () => {
    expect(parseReturnTo(null)).toBeNull();
    expect(parseReturnTo(undefined)).toBeNull();
    expect(parseReturnTo("")).toBeNull();
  });

  it("rejects external URLs and protocol-relative paths", () => {
    expect(parseReturnTo("https://evil.example.com/x")).toBeNull();
    expect(parseReturnTo("//evil.example.com/x")).toBeNull();
    expect(parseReturnTo("http://localhost:3000/events/" + VALID_UUID)).toBeNull();
  });

  it("rejects javascript: and other schemes", () => {
    expect(parseReturnTo("javascript:alert(1)")).toBeNull();
    expect(parseReturnTo("data:text/html,<script>alert(1)</script>")).toBeNull();
  });

  it("rejects path traversal", () => {
    expect(parseReturnTo(`/events/../${VALID_UUID}`)).toBeNull();
    expect(parseReturnTo("..%2F..%2Fadmin")).toBeNull();
  });

  it("rejects non-UUID ids and unknown sections", () => {
    expect(parseReturnTo("/events/not-a-uuid")).toBeNull();
    expect(parseReturnTo(`/admin/${VALID_UUID}`)).toBeNull();
    expect(parseReturnTo(`/events/${VALID_UUID}/extra/segment`)).toBeNull();
  });

  it("rejects list paths (must point at one entity)", () => {
    expect(parseReturnTo("/events")).toBeNull();
    expect(parseReturnTo("/lessons")).toBeNull();
  });

  it("accepts the lesson-create wizard path (template flow return target)", () => {
    expect(parseReturnTo("/lessons/new")).toBe("/lessons/new");
    expect(parseReturnTo(`/lessons/new?event=${VALID_UUID}`)).toBe(
      `/lessons/new?event=${VALID_UUID}`,
    );
  });

  it("rejects other /new routes and malformed wizard paths", () => {
    expect(parseReturnTo("/events/new")).toBeNull();
    expect(parseReturnTo("/templates/new")).toBeNull();
    expect(parseReturnTo("/lessons/new/extra")).toBeNull();
  });
});

describe("withReturnTo", () => {
  it("appends ?return= when href has no query", () => {
    const ret = `/events/${VALID_UUID}`;
    expect(withReturnTo(`/lessons/${VALID_UUID}`, ret)).toBe(
      `/lessons/${VALID_UUID}?return=${encodeURIComponent(ret)}`,
    );
  });

  it("appends &return= when href already has a query", () => {
    const ret = `/events/${VALID_UUID}?tab=lessons`;
    expect(withReturnTo(`/lessons/new?event=${VALID_UUID}`, ret)).toBe(
      `/lessons/new?event=${VALID_UUID}&return=${encodeURIComponent(ret)}`,
    );
  });

  it("leaves href unchanged when returnTo is null", () => {
    expect(withReturnTo(`/lessons/${VALID_UUID}`, null)).toBe(`/lessons/${VALID_UUID}`);
  });
});
