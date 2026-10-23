import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";

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

// Danh sách scene trống → picker render Select với option trống.
beforeEach(() => {
  vi.restoreAllMocks();
  vi.stubGlobal(
    "fetch",
    vi.fn(async () =>
      new Response(JSON.stringify({ content: [], totalElements: 0 }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }),
    ),
  );
});

describe("ReadEditor — animation picker", () => {
  it("renders the scene picker with the empty option selected by default", async () => {
    const onChange = vi.fn();
    const act = makeRead({ text: "Nội dung đọc" });
    renderEditor(<ReadEditor stage={stage} activity={act} onChange={onChange} />);

    const select = await screen.findByLabelText(/cảnh hoạt họa/i);
    expect(select).toHaveValue("");
    // Chọn lại option rỗng không bắn onChange — config giữ nguyên.
    await userEvent.selectOptions(select, "");
    expect(onChange).not.toHaveBeenCalled();
  });

  it("keeps other config keys untouched while the picker mounts", async () => {
    const onChange = vi.fn();
    renderEditor(
      <ReadEditor
        stage={stage}
        activity={makeRead({ text: "Nội dung đọc", customFlag: true })}
        onChange={onChange}
      />,
    );
    await screen.findByLabelText(/cảnh hoạt họa/i);
    expect(onChange).not.toHaveBeenCalled();
  });

  it("disables the picker in readOnly mode", async () => {
    renderEditor(
      <ReadEditor stage={stage} activity={makeRead({})} readOnly onChange={vi.fn()} />,
    );
    expect(await screen.findByLabelText(/cảnh hoạt họa/i)).toBeDisabled();
  });

  it("exposes legacy animationKey field behind the collapsible and edits it", async () => {
    const onChange = vi.fn();
    renderEditor(
      <ReadEditor
        stage={stage}
        activity={makeRead({ text: "x", animationKey: "bach_dang_938_tide_v1" })}
        onChange={onChange}
      />,
    );
    const input = await screen.findByDisplayValue("bach_dang_938_tide_v1");
    await userEvent.type(input, "z");
    const patch = onChange.mock.calls.at(-1)![0] as { config: Record<string, unknown> };
    expect(patch.config.animationKey).toBe("bach_dang_938_tide_v1z");
  });
});
