import { describe, expect, it } from "vitest";

import { EVENT_WORKSPACE_TABS, parseEventTab } from "./types";

describe("parseEventTab", () => {
  it("returns overview for missing/unknown values", () => {
    expect(parseEventTab(null)).toBe("overview");
    expect(parseEventTab(undefined)).toBe("overview");
    expect(parseEventTab("")).toBe("overview");
    expect(parseEventTab("nonsense")).toBe("overview");
    expect(parseEventTab("../../etc")).toBe("overview");
  });

  it("accepts every declared tab slug", () => {
    for (const tab of EVENT_WORKSPACE_TABS) {
      expect(parseEventTab(tab.slug)).toBe(tab.slug);
    }
  });
});
