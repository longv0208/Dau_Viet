import { describe, expect, it } from "vitest";

import { allIds, parseDraft, serializeDraft } from "./draft-model";

describe("parseDraft", () => {
  it("parses empty/missing draft to empty stages with schemaVersion=1", () => {
    for (const raw of ["{}", "", null, undefined, "  "]) {
      const d = parseDraft(raw);
      expect(d.stages).toEqual([]);
      expect(d.schemaVersion).toBe(1);
    }
  });

  it("throws DraftParseError on non-object JSON", () => {
    expect(() => parseDraft("[1,2]")).toThrowError(/JSON object/);
    expect(() => parseDraft("123")).toThrowError(/JSON object/);
    expect(() => parseDraft("{bad")).toThrowError(/JSON hợp lệ/);
  });

  it("round-trips unknown top-level + stage + activity keys", () => {
    const src = JSON.stringify({
      schemaVersion: 1,
      objectives: ["obj"],
      futureField: { nested: true },
      stages: [
        {
          id: "s1",
          type: "CONTEXT",
          title: "T",
          unknownStageKey: 42,
          activities: [
            {
              id: "a1",
              type: "READ",
              config: { text: "x", futureCfg: [1] },
              weird: "kept",
            },
          ],
        },
      ],
    });
    const d = parseDraft(src);
    const out = JSON.parse(serializeDraft(d));
    expect(out.futureField).toEqual({ nested: true });
    expect(out.stages[0].unknownStageKey).toBe(42);
    expect(out.stages[0].activities[0].weird).toBe("kept");
    expect(out.stages[0].activities[0].config.futureCfg).toEqual([1]);
  });

  it("defaults missing stage.activities to []", () => {
    const d = parseDraft(JSON.stringify({ stages: [{ id: "s", type: "CONTEXT" }] }));
    expect(d.stages[0]!.activities).toEqual([]);
  });
});

describe("allIds", () => {
  it("collects stage + activity ids", () => {
    const d = parseDraft(
      JSON.stringify({
        stages: [{ id: "s1", type: "CONTEXT", activities: [{ id: "a1" }, { id: "a2" }] }],
      }),
    );
    expect(allIds(d).sort()).toEqual(["a1", "a2", "s1"]);
  });
});
