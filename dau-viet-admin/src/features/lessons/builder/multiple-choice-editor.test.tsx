import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import type { Activity, Stage } from "./draft-model";
import { MultipleChoiceEditor } from "./activity-editors/multiple-choice-editor";

const stage: Stage = { id: "s1", type: "EVIDENCE", required: true, activities: [] };

function makeMc(config: Record<string, unknown>): Activity {
  return { id: "a1", type: "MULTIPLE_CHOICE", required: true, config };
}

describe("MultipleChoiceEditor", () => {
  it("always emits canonical correctOptionIds + multiSelect flag", async () => {
    const onChange = vi.fn();
    const act = makeMc({
      question: "Q?",
      options: [
        { id: "o1", label: "A" },
        { id: "o2", label: "B" },
      ],
      correctOptionIds: ["o1"],
    });
    render(<MultipleChoiceEditor stage={stage} activity={act} onChange={onChange} />);

    // Switch to "Nhiều đáp án" → canonical key stays correctOptionIds,
    // multiSelect becomes true, legacy multiCorrect is deleted.
    await userEvent.click(screen.getByLabelText(/nhiều đáp án/i));
    const patch = onChange.mock.calls.at(-1)![0] as { config: Record<string, unknown> };
    expect(patch.config.correctOptionIds).toEqual(["o1"]);
    expect(patch.config.multiSelect).toBe(true);
    expect("multiCorrect" in patch.config).toBe(false);
  });

  it("reads legacy multiCorrect drafts and normalizes on save", async () => {
    const onChange = vi.fn();
    const act = makeMc({
      question: "Q?",
      options: [
        { id: "o1", label: "A" },
        { id: "o2", label: "B" },
        { id: "o3", label: "C" },
      ],
      multiCorrect: ["o1", "o3"],
    });
    render(<MultipleChoiceEditor stage={stage} activity={act} onChange={onChange} />);
    // Legacy draft shows multi mode + both answers pre-checked.
    expect(screen.getByLabelText(/nhiều đáp án/i)).toBeChecked();
    expect(screen.getByLabelText("Đáp án đúng 1")).toBeChecked();
    expect(screen.getByLabelText("Đáp án đúng 3")).toBeChecked();
    // Any subsequent write emits canonical keys only.
    await userEvent.click(screen.getByLabelText("Đáp án đúng 2"));
    const patch = onChange.mock.calls.at(-1)![0] as { config: Record<string, unknown> };
    expect(patch.config.correctOptionIds).toEqual(
      expect.arrayContaining(["o1", "o3", "o2"]),
    );
    expect(patch.config.multiSelect).toBe(true);
    expect("multiCorrect" in patch.config).toBe(false);
  });

  it("marks a single correct option", async () => {
    const onChange = vi.fn();
    const act = makeMc({
      question: "Q?",
      options: [
        { id: "o1", label: "A" },
        { id: "o2", label: "B" },
      ],
    });
    render(<MultipleChoiceEditor stage={stage} activity={act} onChange={onChange} />);
    await userEvent.click(screen.getByLabelText("Đáp án đúng 2"));
    const patch = onChange.mock.calls.at(-1)![0] as { config: Record<string, unknown> };
    expect(patch.config.correctOptionIds).toEqual(["o2"]);
  });

  it("keeps ≥2 options and adds new option with valid id", async () => {
    const onChange = vi.fn();
    const act = makeMc({
      question: "Q?",
      options: [
        { id: "o1", label: "A" },
        { id: "o2", label: "B" },
      ],
      correctOptionIds: ["o1"],
    });
    render(<MultipleChoiceEditor stage={stage} activity={act} onChange={onChange} />);
    // Remove disabled khi chỉ còn 2
    expect(screen.getByLabelText("Xoá đáp án 1")).toBeDisabled();
    await userEvent.click(screen.getByRole("button", { name: /thêm đáp án/i }));
    const patch = onChange.mock.calls.at(-1)![0] as {
      config: { options: { id: string }[] };
    };
    expect(patch.config.options).toHaveLength(3);
    expect(patch.config.options[2]!.id).toMatch(/^[a-z0-9][a-z0-9-]{1,63}$/);
  });
});
