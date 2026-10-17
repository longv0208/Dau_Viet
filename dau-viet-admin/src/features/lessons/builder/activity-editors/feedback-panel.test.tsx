import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState } from "react";
import { describe, expect, it, vi } from "vitest";

import type { Activity, Stage } from "../draft-model";
import { FeedbackPanel } from "./feedback-panel";

const stage = { id: "s1", type: "EVIDENCE", activities: [] } as unknown as Stage;

function makeActivity(feedback?: Record<string, unknown>): Activity {
  return {
    id: "a1",
    type: "MULTIPLE_CHOICE",
    required: true,
    config: {},
    feedback,
  } as Activity;
}

/** Wrapper that applies onChange patches — mimics the builder state loop so
 * the controlled textbox re-renders with each emitted value. */
function Controlled({
  initial,
  onChange,
}: {
  initial?: Record<string, unknown>;
  onChange: (p: Partial<Activity>) => void;
}) {
  const [fb, setFb] = useState(initial);
  return (
    <FeedbackPanel
      stage={stage}
      activity={makeActivity(fb)}
      onChange={(p) => {
        if ("feedback" in p) setFb(p.feedback);
        onChange(p);
      }}
    />
  );
}

describe("FeedbackPanel", () => {
  it("writes COMPLETED feedback text into activity.feedback", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(<Controlled onChange={onChange} />);
    // Panel is inside <details> — open it first.
    await user.click(screen.getByText("Phản hồi cho học viên"));
    const box = screen.getByLabelText(/Khi hoàn thành đúng/);
    await user.type(box, "Hoàn-thành-tốt!");
    // Controlled input emits per keystroke; last call carries the full text.
    expect(onChange).toHaveBeenCalled();
    const last = onChange.mock.calls.at(-1)?.[0] as { feedback?: Record<string, string> };
    expect(last.feedback?.COMPLETED).toBe("Hoàn-thành-tốt!");
  });

  it("deletes a key when its textbox is emptied", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(
      <FeedbackPanel
        stage={stage}
        activity={makeActivity({ COMPLETED: "Cũ", INCORRECT: "Giữ" })}
        onChange={onChange}
      />,
    );
    await user.click(screen.getByText("Phản hồi cho học viên"));
    const box = screen.getByLabelText(/Khi hoàn thành đúng/);
    await user.clear(box);
    // Clearing emits the remaining keys only.
    expect(onChange).toHaveBeenLastCalledWith({ feedback: { INCORRECT: "Giữ" } });
  });

  it("emits feedback:undefined when all keys are removed", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(
      <FeedbackPanel
        stage={stage}
        activity={makeActivity({ COMPLETED: "Cũ" })}
        onChange={onChange}
      />,
    );
    await user.click(screen.getByText("Phản hồi cho học viên"));
    await user.clear(screen.getByLabelText(/Khi hoàn thành đúng/));
    expect(onChange).toHaveBeenLastCalledWith({ feedback: undefined });
  });
});
