import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";

import { AnimationPicker } from "./animation-picker";

function wrap(ui: React.ReactElement) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={qc}>{ui}</QueryClientProvider>);
}

const PUBLISHED_SCENE_ID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
const PUBLISHED_VERSION_ID = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";

describe("AnimationPicker", () => {
  it("lists only published scenes with currentVersionId", async () => {
    wrap(<AnimationPicker config={{}} onConfigChange={vi.fn()} />);
    const select = await screen.findByLabelText(/Cảnh hoạt họa/);
    await waitFor(() =>
      expect(screen.getByText(/Trận thủy chiến Bạch Đằng 938 \(v1\)/)).toBeInTheDocument(),
    );
    const options = Array.from(select.querySelectorAll("option")).map((o) => o.textContent);
    // DRAFT scene must not be pickable.
    expect(options.join(" ")).not.toMatch(/Cảnh nháp chưa xuất bản/);
    expect(options.join(" ")).toMatch(/Hành trình về Thăng Long 1010 \(v2\)/);
  });

  it("writes sceneId + pinned currentVersionId + playbackMode on select", async () => {
    const user = userEvent.setup();
    const onConfigChange = vi.fn();
    wrap(<AnimationPicker config={{}} onConfigChange={onConfigChange} />);
    await waitFor(() =>
      screen.getByText(/Trận thủy chiến Bạch Đằng 938/),
    );
    await user.selectOptions(screen.getByLabelText(/Cảnh hoạt họa/), PUBLISHED_SCENE_ID);
    const patch = onConfigChange.mock.calls[0]![0] as Record<string, unknown>;
    expect(patch.animationSceneId).toBe(PUBLISHED_SCENE_ID);
    expect(patch.animationSceneVersionId).toBe(PUBLISHED_VERSION_ID);
    expect(patch.playbackMode).toBe("AUTO");
    expect(patch).not.toHaveProperty("animationKey");
  });

  it("drops the legacy animationKey when a data-driven scene is chosen", async () => {
    const user = userEvent.setup();
    const onConfigChange = vi.fn();
    wrap(
      <AnimationPicker
        config={{ animationKey: "bach_dang_938_tide_v1" }}
        onConfigChange={onConfigChange}
      />,
    );
    await waitFor(() => screen.getByText(/Trận thủy chiến Bạch Đằng 938/));
    await user.selectOptions(screen.getByLabelText(/Cảnh hoạt họa/), PUBLISHED_SCENE_ID);
    const patch = onConfigChange.mock.calls.at(-1)![0] as Record<string, unknown>;
    expect(patch.animationSceneId).toBe(PUBLISHED_SCENE_ID);
    expect(patch).not.toHaveProperty("animationKey");
  });

  it("clears all animation keys when the empty option is chosen", async () => {
    const user = userEvent.setup();
    const onConfigChange = vi.fn();
    wrap(
      <AnimationPicker
        config={{
          animationSceneId: PUBLISHED_SCENE_ID,
          animationSceneVersionId: PUBLISHED_VERSION_ID,
          playbackMode: "STEPPED",
        }}
        onConfigChange={onConfigChange}
      />,
    );
    await waitFor(() => screen.getByText(/Trận thủy chiến Bạch Đằng 938/));
    await user.selectOptions(screen.getByLabelText(/Cảnh hoạt họa/), "");
    const patch = onConfigChange.mock.calls.at(-1)![0] as Record<string, unknown>;
    expect(patch).not.toHaveProperty("animationSceneId");
    expect(patch).not.toHaveProperty("animationSceneVersionId");
    expect(patch).not.toHaveProperty("playbackMode");
  });

  it("shows an error + retry instead of the empty hint when the list fails", async () => {
    server.use(
      http.get("*/api/proxy/admin/animation-scenes", () =>
        HttpResponse.json({ code: "INTERNAL_ERROR" }, { status: 500 }),
      ),
    );
    wrap(<AnimationPicker config={{}} onConfigChange={vi.fn()} />);
    await waitFor(() =>
      expect(screen.getByText(/Không tải được danh sách cảnh/)).toBeInTheDocument(),
    );
    expect(screen.getByRole("button", { name: /Thử lại/ })).toBeInTheDocument();
    // The "no published scenes" hint must NOT masquerade as the error state.
    expect(screen.queryByText(/Chưa có cảnh nào đã xuất bản/)).not.toBeInTheDocument();
  });

  it("filters by search text via the server-side q param", async () => {
    const user = userEvent.setup();
    wrap(<AnimationPicker config={{}} onConfigChange={vi.fn()} />);
    await waitFor(() => screen.getByText(/Trận thủy chiến Bạch Đằng 938/));
    await user.type(screen.getByPlaceholderText(/Tìm cảnh theo tiêu đề/), "Thăng Long");
    await waitFor(() => {
      const options = Array.from(
        screen.getByLabelText(/Cảnh hoạt họa/).querySelectorAll("option"),
      ).map((o) => o.textContent);
      expect(options.join(" ")).toMatch(/Thăng Long/);
      expect(options.join(" ")).not.toMatch(/Bạch Đằng/);
    });
  });
});
