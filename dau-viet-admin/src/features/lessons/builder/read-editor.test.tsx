import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import type { Activity, Stage } from "./draft-model";
import { ReadEditor } from "./activity-editors/read-editor";

const stage: Stage = { id: "s1", type: "CONTEXT", required: true, activities: [] };

function makeRead(config: Record<string, unknown>): Activity {
  return { id: "r1", type: "READ", required: false, config };
}

function renderEditor(ui: React.ReactElement) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={client}>{ui}</QueryClientProvider>);
}

describe("ReadEditor — animationKey", () => {
  it("shows the current animationKey and emits it preserving other config", async () => {
    const onChange = vi.fn();
    const act = makeRead({
      text: "Nội dung đọc",
      animationKey: "bach_dang_938_tide_v1",
      customFlag: true,
    });
    renderEditor(<ReadEditor stage={stage} activity={act} onChange={onChange} />);

    const input = screen.getByLabelText(/mã hoạt họa/i);
    expect(input).toHaveValue("bach_dang_938_tide_v1");

    // Controlled input without a stateful parent: each keystroke starts from
    // the same prop value — a single char is enough to prove emission.
    await userEvent.type(input, "x");
    const patch = onChange.mock.calls.at(-1)![0] as {
      config: Record<string, unknown>;
    };
    expect(patch.config.animationKey).toBe("bach_dang_938_tide_v1x");
    // text + any other config keys are preserved by the spread.
    expect(patch.config.text).toBe("Nội dung đọc");
    expect(patch.config.customFlag).toBe(true);
  });

  it("clearing the field removes animationKey instead of storing ''", async () => {
    const onChange = vi.fn();
    const act = makeRead({ text: "x", animationKey: "bach_dang_938_tide_v1" });
    renderEditor(<ReadEditor stage={stage} activity={act} onChange={onChange} />);

    await userEvent.clear(screen.getByLabelText(/mã hoạt họa/i));
    const patch = onChange.mock.calls.at(-1)![0] as {
      config: Record<string, unknown>;
    };
    expect("animationKey" in patch.config).toBe(false);
    expect(patch.config.text).toBe("x");
  });

  it("renders an empty field when animationKey is absent", () => {
    const onChange = vi.fn();
    renderEditor(
      <ReadEditor stage={stage} activity={makeRead({ text: "x" })} onChange={onChange} />,
    );
    expect(screen.getByLabelText(/mã hoạt họa/i)).toHaveValue("");
  });

  it("disables the field in readOnly mode", () => {
    renderEditor(
      <ReadEditor
        stage={stage}
        activity={makeRead({ animationKey: "k_v1" })}
        readOnly
        onChange={vi.fn()}
      />,
    );
    expect(screen.getByLabelText(/mã hoạt họa/i)).toBeDisabled();
  });
});
