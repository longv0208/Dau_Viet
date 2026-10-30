import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState } from "react";
import { describe, expect, it, vi } from "vitest";

import { defaultFeedbackForActivity, type Activity, type Stage } from "../draft-model";
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
  it("shows pre-populated default feedback and subtitle without manual entry", async () => {
    const user = userEvent.setup();
    render(<Controlled onChange={vi.fn()} />);
    expect(
      screen.getByText(/Đã có sẵn phản hồi mặc định — nhấn để xem hoặc chỉnh sửa/i),
    ).toBeInTheDocument();
    await user.click(screen.getByText("Phản hồi cho học viên"));
    const defaults = defaultFeedbackForActivity("MULTIPLE_CHOICE");
    expect(screen.getByLabelText(/Khi hoàn thành đúng/)).toHaveValue(defaults.COMPLETED);
    expect(screen.getByLabelText(/Khi trả lời chưa đúng/)).toHaveValue(defaults.INCORRECT);
    expect(screen.getByLabelText(/Khi hết lượt thử/)).toHaveValue(defaults.EXHAUSTED);
  });

  it("writes custom COMPLETED feedback text into activity.feedback", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(<Controlled onChange={onChange} />);
    await user.click(screen.getByText("Phản hồi cho học viên"));
    const box = screen.getByLabelText(/Khi hoàn thành đúng/);
    await user.clear(box);
    await user.type(box, "Hoàn-thành-tốt!");
    expect(onChange).toHaveBeenCalled();
    const last = onChange.mock.calls.at(-1)?.[0] as { feedback?: Record<string, string> };
    expect(last.feedback?.COMPLETED).toBe("Hoàn-thành-tốt!");
  });

  it("restores default feedback when an emptied field loses focus (blur) or reset button is clicked", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    const defaults = defaultFeedbackForActivity("MULTIPLE_CHOICE");
    render(
      <Controlled
        initial={{ COMPLETED: "Câu tùy chỉnh", INCORRECT: "Giữ", EXHAUSTED: "Hết" }}
        onChange={onChange}
      />,
    );
    await user.click(screen.getByText("Phản hồi cho học viên"));
    const box = screen.getByLabelText(/Khi hoàn thành đúng/);
    await user.clear(box);
    await user.tab();
    expect(onChange).toHaveBeenLastCalledWith({
      feedback: {
        COMPLETED: defaults.COMPLETED,
        INCORRECT: "Giữ",
        EXHAUSTED: "Hết",
      },
    });

    await user.click(screen.getByRole("button", { name: /khôi phục mặc định/i }));
    expect(onChange).toHaveBeenLastCalledWith({ feedback: defaults });
  });
});
