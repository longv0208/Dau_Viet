import { act, renderHook } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { makeActivity, makeStage, useBuilder } from "./use-builder";
import { parseDraft } from "./draft-model";

const ID_PATTERN = /^[a-z0-9][a-z0-9-]{1,63}$/;

function setup(json = "{}") {
  const draft = parseDraft(json);
  return renderHook(() => useBuilder(draft, 3));
}

describe("useBuilder", () => {
  it("starts clean with first stage selected", () => {
    const { result } = setup(
      JSON.stringify({ stages: [{ id: "s1", type: "CONTEXT", activities: [] }] }),
    );
    expect(result.current.state.dirty).toBe(false);
    expect(result.current.state.rowVersion).toBe(3);
    expect(result.current.state.selectedStageId).toBe("s1");
  });

  it("adds a stage with a backend-pattern slug id and selects it", () => {
    const { result } = setup();
    act(() => {
      result.current.actions.addStage(makeStage("CONTEXT", []));
    });
    const st = result.current.state.draft.stages[0]!;
    expect(ID_PATTERN.test(st.id)).toBe(true);
    expect(st.required).toBe(true);
    expect(result.current.state.selectedStageId).toBe(st.id);
    expect(result.current.state.dirty).toBe(true);
  });

  it("duplicateStage re-ids stage + activities and appends (bản sao) title", () => {
    const { result } = setup(
      JSON.stringify({
        stages: [
          {
            id: "s1",
            type: "CONTEXT",
            title: "Gốc",
            activities: [{ id: "a1", type: "READ" }],
          },
        ],
      }),
    );
    act(() => result.current.actions.duplicateStage("s1"));
    const [orig, copy] = result.current.state.draft.stages;
    expect(copy!.id).not.toBe(orig!.id);
    expect(copy!.title).toBe("Gốc (bản sao)");
    expect(copy!.activities[0]!.id).not.toBe("a1");
    expect(ID_PATTERN.test(copy!.id)).toBe(true);
    expect(ID_PATTERN.test(copy!.activities[0]!.id)).toBe(true);
  });

  it("duplicateStage remaps internal nextStageIds and leaves the original untouched", () => {
    const { result } = setup(
      JSON.stringify({
        stages: [
          { id: "s1", type: "CONTEXT", activities: [], nextStageIds: ["s2"] },
          {
            id: "s2",
            type: "EVIDENCE",
            activities: [
              { id: "a1", type: "READ" },
              { id: "a2", type: "READ" },
            ],
            nextStageIds: ["s2", "s3"],
          },
          { id: "s3", type: "CONCLUSION", activities: [] },
        ],
      }),
    );
    act(() => result.current.actions.duplicateStage("s2"));
    const stages = result.current.state.draft.stages;
    const orig = stages[1]!;
    const copy = stages[2]!;

    // Id mới đôi một khác nhau và unique toàn draft.
    const allIds = stages.flatMap((s) => [s.id, ...s.activities.map((a) => a.id)]);
    expect(new Set(allIds).size).toBe(allIds.length);
    expect(copy.activities.map((a) => a.id)).not.toContain("a1");
    expect(copy.activities.map((a) => a.id)).not.toContain("a2");

    // Self-loop "s2" → id mới của bản sao; tham chiếu ngoài ("s3") giữ nguyên.
    expect(copy.nextStageIds).toEqual([copy.id, "s3"]);

    // Stage gốc không bị đụng vào.
    expect(orig.id).toBe("s2");
    expect(orig.nextStageIds).toEqual(["s2", "s3"]);
    expect(orig.activities.map((a) => a.id)).toEqual(["a1", "a2"]);
  });

  it("removeStage prunes nextStageIds + completion.requiredStageIds", () => {
    const { result } = setup(
      JSON.stringify({
        stages: [
          { id: "s1", type: "CONTEXT", activities: [], nextStageIds: ["s2"] },
          { id: "s2", type: "EVIDENCE", activities: [] },
        ],
        completion: { requireAllRequiredStages: false, requiredStageIds: ["s2"] },
      }),
    );
    act(() => result.current.actions.removeStage("s2"));
    const st = result.current.state.draft;
    expect(st.stages).toHaveLength(1);
    expect(st.stages[0]!.nextStageIds).toEqual([]);
    expect(st.completion?.requiredStageIds).toEqual([]);
    // s1 vẫn được chọn (không bị xoá); selectedActivityId được reset.
    expect(result.current.state.selectedStageId).toBe("s1");
    expect(result.current.state.selectedActivityId).toBeNull();
  });

  it("moves stages and activities within bounds", () => {
    const { result } = setup(
      JSON.stringify({
        stages: [
          { id: "s1", type: "CONTEXT", activities: [{ id: "a1" }, { id: "a2" }] },
          { id: "s2", type: "EVIDENCE", activities: [] },
        ],
      }),
    );
    act(() => result.current.actions.moveStage("s1", 1));
    expect(result.current.state.draft.stages.map((s) => s.id)).toEqual(["s2", "s1"]);
    act(() => result.current.actions.moveStage("s1", 1)); // out of bounds — no-op
    expect(result.current.state.draft.stages.map((s) => s.id)).toEqual(["s2", "s1"]);

    act(() => {
      result.current.actions.selectStage("s2");
      result.current.actions.selectStage("s1");
      result.current.actions.moveActivity("s1", "a2", -1);
    });
    const s1 = result.current.state.draft.stages.find((s) => s.id === "s1")!;
    expect(s1.activities.map((a) => a.id)).toEqual(["a2", "a1"]);
  });

  it("markSaved clears dirty/errors and bumps rowVersion", () => {
    const { result } = setup();
    act(() => result.current.actions.addStage(makeStage("CONTEXT", [])));
    const rev = result.current.state.revision;
    act(() => result.current.actions.setErrors([{ path: "p", code: "c", message: "m" }]));
    act(() => result.current.actions.markSaved(4, rev));
    expect(result.current.state.dirty).toBe(false);
    expect(result.current.state.rowVersion).toBe(4);
    expect(result.current.state.serverErrors).toEqual([]);
    expect(result.current.state.lastSavedAt).toBeTruthy();
  });

  it("markSaved keeps dirty when edits happened during a pending save", () => {
    const { result } = setup(
      JSON.stringify({ stages: [{ id: "s1", type: "CONTEXT", activities: [] }] }),
    );
    // Edit 1 → revision 1 → save bắt đầu, capture revision 1.
    act(() => result.current.actions.updateStage("s1", { title: "A" }));
    const savedRev = result.current.state.revision;
    // Edit 2 trong lúc save đang chạy → revision 2.
    act(() => result.current.actions.updateStage("s1", { title: "B" }));
    // PUT thành công với revision cũ → dirty phải còn nguyên.
    act(() => result.current.actions.markSaved(4, savedRev));
    expect(result.current.state.dirty).toBe(true);
    expect(result.current.state.draft.stages[0]!.title).toBe("B");
    // Save lần 2 với revision mới nhất → sạch.
    const latest = result.current.state.revision;
    act(() => result.current.actions.markSaved(5, latest));
    expect(result.current.state.dirty).toBe(false);
  });

  it("mergeStages appends template stages and marks dirty", () => {
    const { result } = setup(
      JSON.stringify({
        stages: [{ id: "s1", type: "CONTEXT", activities: [] }],
      }),
    );
    const seeded = [
      {
        id: "tpl-context",
        type: "CONTEXT" as const,
        title: "Bối cảnh (mẫu)",
        required: true,
        activities: [],
        nextStageIds: ["tpl-evidence"],
      },
      {
        id: "tpl-evidence",
        type: "EVIDENCE" as const,
        required: true,
        activities: [],
      },
    ];
    act(() => result.current.actions.mergeStages(seeded));
    const st = result.current.state.draft;
    expect(st.stages.map((s) => s.id)).toEqual(["s1", "tpl-context", "tpl-evidence"]);
    // nextStageIds của stage seed được giữ nguyên (template-seed-button đã remap trước).
    expect(st.stages[1]!.nextStageIds).toEqual(["tpl-evidence"]);
    expect(result.current.state.dirty).toBe(true);
    // Selection giữ nguyên stage đang chọn (s1).
    expect(result.current.state.selectedStageId).toBe("s1");
  });

  it("makeActivity honors ID_PATTERN and uniqueness", () => {
    const a = makeActivity("READ", ["act-x"]);
    expect(ID_PATTERN.test(a.id)).toBe(true);
    expect(a.id).not.toBe("act-x");
    expect(a.type).toBe("READ");
  });
});
