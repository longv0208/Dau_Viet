import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState } from "react";
import { describe, expect, it, vi } from "vitest";

import {
  STAGE_TYPES,
  STAGE_ALLOWED_ACTIVITIES,
  parseDraft,
} from "@/features/lessons/builder/draft-model";
import { STAGE_LABELS, ACTIVITY_LABELS } from "@/features/lessons/builder/labels";

import { TemplateDesigner } from "./template-designer";
import {
  ALL_ACTIVITIES_COVERED,
  buildPresetJson,
  isNonLinearDraft,
  stageMatches,
  type Stage,
} from "./template-catalog";

function emptyStage(id: string, type: Stage["type"], title = ""): Stage {
  return { id, type, title, required: true, activities: [], nextStageIds: [] };
}

type SourceDraft = Parameters<typeof TemplateDesigner>[0]["sourceDraft"];

function renderDesigner(initial: Stage[], sourceDraft?: SourceDraft) {
  const onChange = vi.fn();
  let current = initial;
  function Wrapper() {
    const [stages, setStages] = useState(current);
    return (
      <TemplateDesigner
        stages={stages}
        onChange={(next) => {
          current = next;
          onChange(next);
          setStages(next);
        }}
        sourceDraft={sourceDraft}
      />
    );
  }
  const utils = render(<Wrapper />);
  return { ...utils, onChange, getStages: () => current };
}

describe("catalogue integrity", () => {
  it("covers all 9 stage types and every declared activity type", () => {
    expect(STAGE_TYPES).toHaveLength(9);
    expect(ALL_ACTIVITIES_COVERED).toBe(true);
  });

  it("stageMatches finds stages by stage label and by activity label", () => {
    expect(stageMatches("EVIDENCE", "bằng chứng", STAGE_LABELS.EVIDENCE, (t) => ACTIVITY_LABELS[t])).toBe(true);
    expect(stageMatches("EVIDENCE", "trắc nghiệm", STAGE_LABELS.EVIDENCE, (t) => ACTIVITY_LABELS[t])).toBe(true);
    expect(stageMatches("EVIDENCE", "xyz-không-có", STAGE_LABELS.EVIDENCE, (t) => ACTIVITY_LABELS[t])).toBe(false);
  });
});

describe("buildPresetJson", () => {
  it("serializes stages WITH their activities and linear nextStageIds", () => {
    const stages: Stage[] = [
      {
        id: "s1",
        type: "CONTEXT",
        title: "Bối cảnh",
        required: true,
        activities: [
          { id: "a1", type: "READ", required: false, instruction: "", config: {} },
        ],
        nextStageIds: [],
      },
      {
        id: "s2",
        type: "CONCLUSION",
        title: "Kết luận",
        required: true,
        activities: [
          { id: "a2", type: "CER_CHOICE", required: true, instruction: "", config: {} },
        ],
        nextStageIds: [],
      },
    ];
    const json = buildPresetJson(stages);
    const draft = parseDraft(json);
    expect(draft.stages).toHaveLength(2);
    expect(draft.stages[0]!.activities).toHaveLength(1);
    expect(draft.stages[0]!.activities[0]!.type).toBe("READ");
    expect(draft.stages[0]!.nextStageIds).toEqual(["s2"]);
    expect(draft.stages[1]!.nextStageIds).toEqual([]);
    // Round-trip: re-parse keeps the activity skeletons for lesson seeding.
    expect(draft.stages[1]!.activities[0]!.id).toBe("a2");
  });
});

describe("isNonLinearDraft", () => {
  it("detects linear chains as editable", () => {
    const draft = parseDraft(
      JSON.stringify({
        schemaVersion: 1,
        stages: [
          { id: "a", type: "CONTEXT", activities: [], nextStageIds: ["b"] },
          { id: "b", type: "CONCLUSION", activities: [], nextStageIds: [] },
        ],
      }),
    );
    expect(isNonLinearDraft(draft)).toBe(false);
  });

  it("detects branches, skips and dead-ends as non-linear", () => {
    const branch = parseDraft(
      JSON.stringify({
        schemaVersion: 1,
        stages: [
          { id: "a", type: "CONTEXT", activities: [], nextStageIds: ["b", "c"] },
          { id: "b", type: "EVIDENCE", activities: [], nextStageIds: ["c"] },
          { id: "c", type: "CONCLUSION", activities: [], nextStageIds: [] },
        ],
      }),
    );
    expect(isNonLinearDraft(branch)).toBe(true);

    const deadEnd = parseDraft(
      JSON.stringify({
        schemaVersion: 1,
        stages: [
          { id: "a", type: "CONTEXT", activities: [], nextStageIds: [] },
          { id: "b", type: "CONCLUSION", activities: [], nextStageIds: [] },
        ],
      }),
    );
    expect(isNonLinearDraft(deadEnd)).toBe(true);
  });
});

describe("TemplateDesigner", () => {
  it("renders all 9 stage cards with their allowed activities already expanded", async () => {
    renderDesigner([]);
    for (const t of STAGE_TYPES) {
      expect(screen.getByRole("heading", { name: STAGE_LABELS[t].label })).toBeInTheDocument();
      for (const a of STAGE_ALLOWED_ACTIVITIES[t]) {
        // Activity rows show name + description without extra clicks.
        expect(
          screen.getAllByText(ACTIVITY_LABELS[a].label).length,
        ).toBeGreaterThanOrEqual(1);
      }
    }
  });

  it("filters the library by activity name", async () => {
    renderDesigner([]);
    const search = screen.getByLabelText("Tìm giai đoạn hoặc hoạt động");
    await userEvent.type(search, "ghép cặp");
    // REASONING contains MATCHING ("Ghép cặp"); unrelated stages hide.
    expect(screen.getByRole("heading", { name: "Suy luận" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Khám phá" })).not.toBeInTheDocument();
  });

  it("a quick-nav chip filters the library down to that stage only", async () => {
    renderDesigner([]);
    await userEvent.click(screen.getByRole("button", { name: "Khám phá" }));
    // Only the picked stage card stays — the other 8 are filtered out.
    expect(screen.getByRole("heading", { name: "Khám phá" })).toBeInTheDocument();
    for (const t of STAGE_TYPES.filter((s) => s !== "DISCOVERY")) {
      expect(
        screen.queryByRole("heading", { name: STAGE_LABELS[t].label }),
      ).not.toBeInTheDocument();
    }
    // Bấm lại chip đang chọn → hiện lại toàn bộ thư viện.
    await userEvent.click(screen.getByRole("button", { name: "Khám phá" }));
    for (const t of STAGE_TYPES) {
      expect(screen.getByRole("heading", { name: STAGE_LABELS[t].label })).toBeInTheDocument();
    }
  });

  it("adds a stage from the library card into the canvas", async () => {
    const { getStages } = renderDesigner([]);
    await userEvent.click(
      screen.getAllByRole("button", { name: /Thêm giai đoạn Kết luận/ })[0]!,
    );
    await waitFor(() => expect(getStages()).toHaveLength(1));
    expect(getStages()[0]!.type).toBe("CONCLUSION");
  });

  it("adds an activity: creates a stage of that type when none exists", async () => {
    const { getStages } = renderDesigner([]);
    // EVIDENCE stage allows EVIDENCE_SELECT — press its per-activity add.
    await userEvent.click(
      screen.getAllByRole("button", { name: /Thêm hoạt động Chọn bằng chứng/ })[0]!,
    );
    await waitFor(() => expect(getStages()).toHaveLength(1));
    expect(getStages()[0]!.type).toBe("EVIDENCE");
    expect(getStages()[0]!.activities).toHaveLength(1);
    expect(getStages()[0]!.activities[0]!.type).toBe("EVIDENCE_SELECT");
  });

  it("adds an activity into the single existing stage of the same type", async () => {
    const { getStages } = renderDesigner([emptyStage("st1", "CONTEXT", "Bối cảnh")]);
    await userEvent.click(
      screen.getAllByRole("button", { name: /Thêm hoạt động Quan sát hình ảnh/ })[0]!,
    );
    await waitFor(() => expect(getStages()[0]!.activities).toHaveLength(1));
    expect(getStages()[0]!.activities[0]!.type).toBe("VIEW_IMAGE");
  });

  it("asks which stage when several share the type and none is selected", async () => {
    const { getStages } = renderDesigner([
      emptyStage("c1", "CONTEXT", "Bối cảnh một"),
      emptyStage("c2", "CONTEXT", "Bối cảnh hai"),
    ]);
    await userEvent.click(
      screen.getAllByRole("button", { name: /Thêm hoạt động Đọc tư liệu/ })[0]!,
    );
    // Picker dialog lists both candidates — no silent first-match add.
    await waitFor(() =>
      expect(screen.getByRole("dialog", { name: "Chọn giai đoạn nhận hoạt động" })).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByText("Giai đoạn 2 — Bối cảnh hai"));
    await waitFor(() => expect(getStages()[1]!.activities).toHaveLength(1));
    expect(getStages()[0]!.activities).toHaveLength(0);
    expect(getStages()[1]!.activities[0]!.type).toBe("READ");
  });

  it("removes activities and stages (stage delete asks confirmation)", async () => {
    const withAct: Stage = {
      ...emptyStage("s1", "EVIDENCE", "Bằng chứng"),
      activities: [{ id: "a1", type: "READ", required: false, instruction: "", config: {} }],
    };
    const confirmSpy = vi.spyOn(window, "confirm").mockReturnValue(true);
    const { getStages } = renderDesigner([withAct]);
    await userEvent.click(screen.getByRole("button", { name: "Xoá hoạt động Đọc tư liệu" }));
    await waitFor(() => expect(getStages()[0]!.activities).toHaveLength(0));
    await userEvent.click(screen.getByRole("button", { name: "Xoá giai đoạn 1" }));
    await waitFor(() => expect(getStages()).toHaveLength(0));
    confirmSpy.mockRestore();
  });

  it("locks the canvas read-only for non-linear presets", () => {
    const branchy = parseDraft(
      JSON.stringify({
        schemaVersion: 1,
        stages: [
          { id: "a", type: "CONTEXT", title: "A", activities: [], nextStageIds: ["b", "c"] },
          { id: "b", type: "EVIDENCE", title: "B", activities: [], nextStageIds: ["c"] },
          { id: "c", type: "CONCLUSION", title: "C", activities: [], nextStageIds: [] },
        ],
      }),
    );
    renderDesigner(branchy.stages, branchy);
    expect(screen.getByText(/chế độ chỉ đọc/)).toBeInTheDocument();
  });
});
