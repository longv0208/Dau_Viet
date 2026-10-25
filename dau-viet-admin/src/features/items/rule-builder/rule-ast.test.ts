import { describe, expect, it } from "vitest";

import {
  astToForm,
  describeLeaf,
  formToAst,
  isLeafComplete,
  leafToJson,
  leafUsesEvent,
  type BuilderState,
  type LeafForm,
} from "./rule-ast";

let seq = 0;
const leaf = (partial: Partial<LeafForm> & { type: LeafForm["type"] }): LeafForm => ({
  localId: `t-${seq++}`,
  ...partial,
});

describe("leafToJson", () => {
  it("chỉ xuất trường thuộc shape của type (strict contract)", () => {
    expect(
      leafToJson(leaf({ type: "LESSON_COMPLETED", lessonId: "l1", eventId: "e1" })),
    ).toEqual({ type: "LESSON_COMPLETED", lessonId: "l1" });
    expect(
      leafToJson(leaf({ type: "COLLECTION_COUNT", threshold: 3, eventId: "e1" })),
    ).toEqual({ type: "COLLECTION_COUNT", threshold: 3 });
    expect(
      leafToJson(leaf({ type: "EVENT_COMPLETED", eventId: "e1", threshold: 5 })),
    ).toEqual({ type: "EVENT_COMPLETED", eventId: "e1" });
  });

  it("SPECIFIC_EVIDENCE_SET mang eventId + evidenceIds", () => {
    expect(
      leafToJson(
        leaf({ type: "SPECIFIC_EVIDENCE_SET", eventId: "e1", evidenceIds: ["a", "b"] }),
      ),
    ).toEqual({ type: "SPECIFIC_EVIDENCE_SET", eventId: "e1", evidenceIds: ["a", "b"] });
  });
});

describe("formToAst", () => {
  it("0 leaf → null", () => {
    expect(formToAst({ root: "all", children: [] })).toBeNull();
  });

  it("1 leaf → unwrap, không bọc operator", () => {
    const state: BuilderState = {
      root: "all",
      children: [leaf({ type: "LESSON_COUNT", threshold: 5 })],
    };
    expect(formToAst(state)).toEqual({ type: "LESSON_COUNT", threshold: 5 });
  });

  it("nhiều leaf → bọc all/any", () => {
    const state: BuilderState = {
      root: "any",
      children: [
        leaf({ type: "COLLECTION_COUNT", threshold: 3 }),
        leaf({ type: "EVENT_COMPLETED", eventId: "e1" }),
      ],
    };
    expect(formToAst(state)).toEqual({
      any: [
        { type: "COLLECTION_COUNT", threshold: 3 },
        { type: "EVENT_COMPLETED", eventId: "e1" },
      ],
    });
  });
});

describe("astToForm", () => {
  it("parse leaf đơn", () => {
    const f = astToForm({ type: "LESSON_COMPLETED", lessonId: "l9" });
    expect(f?.root).toBe("all");
    expect(f?.children).toHaveLength(1);
    expect(f?.children[0]?.lessonId).toBe("l9");
  });

  it("parse operator node", () => {
    const f = astToForm({
      all: [
        { type: "EVENT_EVIDENCE_COUNT", eventId: "e2", threshold: 4 },
        { type: "TOTAL_EVENTS_MASTERED", threshold: 2 },
      ],
    });
    expect(f?.root).toBe("all");
    expect(f?.children[0]?.type).toBe("EVENT_EVIDENCE_COUNT");
    expect(f?.children[0]?.eventId).toBe("e2");
    expect(f?.children[1]?.threshold).toBe(2);
  });

  it("json rỗng/không phải object → null", () => {
    expect(astToForm(null)).toBeNull();
    expect(astToForm("x")).toBeNull();
    expect(astToForm({})).toBeNull();
  });

  it("roundtrip form→ast→form giữ params", () => {
    const state: BuilderState = {
      root: "any",
      children: [
        leaf({
          type: "SPECIFIC_EVIDENCE_SET",
          eventId: "e1",
          evidenceIds: ["a1", "a2"],
        }),
        leaf({ type: "LESSON_MASTERED", lessonId: "l1", threshold: 80 }),
      ],
    };
    const back = astToForm(formToAst(state));
    expect(back?.root).toBe("any");
    expect(back?.children.map((c) => c.type)).toEqual([
      "SPECIFIC_EVIDENCE_SET",
      "LESSON_MASTERED",
    ]);
    expect(back?.children[0]?.evidenceIds).toEqual(["a1", "a2"]);
    expect(back?.children[1]?.threshold).toBe(80);
  });
});

describe("isLeafComplete", () => {
  it("bắt buộc trường theo type", () => {
    expect(isLeafComplete(leaf({ type: "LESSON_COMPLETED" }))).toBe(false);
    expect(isLeafComplete(leaf({ type: "LESSON_COMPLETED", lessonId: "x" }))).toBe(true);
    expect(isLeafComplete(leaf({ type: "LESSON_COUNT", threshold: 0 }))).toBe(false);
    expect(isLeafComplete(leaf({ type: "LESSON_COUNT", threshold: 2 }))).toBe(true);
    expect(
      isLeafComplete(leaf({ type: "SPECIFIC_EVIDENCE_SET", eventId: "e", evidenceIds: [] })),
    ).toBe(false);
    expect(
      isLeafComplete(
        leaf({ type: "SPECIFIC_EVIDENCE_SET", eventId: "e", evidenceIds: ["v"] }),
      ),
    ).toBe(true);
  });
});

describe("leafUsesEvent", () => {
  it("event-scoped leaf types", () => {
    expect(leafUsesEvent("EVENT_COMPLETED")).toBe(true);
    expect(leafUsesEvent("EVENT_EVIDENCE_COUNT")).toBe(true);
    expect(leafUsesEvent("SPECIFIC_EVIDENCE_SET")).toBe(true);
    expect(leafUsesEvent("COLLECTION_COUNT")).toBe(false);
  });
});

describe("describeLeaf", () => {
  it("mô tả tiếng Việt kèm tên tra cứu", () => {
    const l = leaf({ type: "EVENT_MASTERED", eventId: "e1" });
    const text = describeLeaf(l, { eventTitle: (id) => (id === "e1" ? "Chiến thắng Điện Biên Phủ" : undefined) });
    expect(text).toContain("Chiến thắng Điện Biên Phủ");
    expect(describeLeaf(l)).toContain("sự kiện đã chọn");
  });
});
