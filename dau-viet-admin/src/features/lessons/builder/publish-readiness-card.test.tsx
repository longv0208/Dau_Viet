import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HttpResponse, http } from "msw";
import { useState } from "react";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { parseDraft } from "./draft-model";
import { PublishReadinessCard } from "./publish-readiness-card";
import { draftFixture } from "@/test/fixtures";

const LESSON_ID = "33333333-3333-3333-3333-333333333333";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
}));

function renderCard(props?: {
  draft?: ReturnType<typeof parseDraft> | null;
  revision?: number;
  onJump?: (s: string | null, a: string | null) => void;
}) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <PublishReadinessCard
        lessonId={LESSON_ID}
        draft={props?.draft}
        revision={props?.revision}
        onJump={props?.onJump}
      />
    </QueryClientProvider>,
  );
}

describe("PublishReadinessCard", () => {
  it("renders structured summary from Map — not [object Object]", async () => {
    authStore.setAccessToken("t", 900);
    renderCard();
    await userEvent.click(screen.getByRole("button", { name: /kiểm tra xuất bản/i }));
    await waitFor(() => screen.getByText(/Chưa sẵn sàng xuất bản/));
    expect(screen.getByText("Số giai đoạn")).toBeInTheDocument();
    expect(screen.getByText("Số hoạt động")).toBeInTheDocument();
    expect(screen.queryByText(/\[object Object\]/)).toBeNull();
  });

  it("shows blocking errors section + click jumps to resolved stage/activity", async () => {
    authStore.setAccessToken("t", 900);
    const draft = parseDraft(draftFixture);
    const onJump = vi.fn();
    renderCard({ draft, onJump });
    await userEvent.click(screen.getByRole("button", { name: /kiểm tra xuất bản/i }));
    await waitFor(() => screen.getByText(/Lỗi chặn xuất bản \(1\)/));

    // Path stages[3] resolves to the 4th stage id in draftFixture.
    const errItem = screen.getByText(/NO_REQUIRED_ACTIVITY/).closest("button");
    expect(errItem).not.toBeNull();
    await userEvent.click(errItem!);
    expect(onJump).toHaveBeenCalledWith("stage-conclusion", null);
  });

  it("renders 'Đi tới xuất bản' link only when ready", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.post(`*/api/proxy/admin/lessons/${LESSON_ID}/validate`, () =>
        HttpResponse.json({
          ready: true,
          errors: [],
          warnings: [],
          summary: { stageCount: 1, activityCount: 1, errorCount: 0, warningCount: 0 },
        }),
      ),
    );
    renderCard();
    await userEvent.click(screen.getByRole("button", { name: /kiểm tra xuất bản/i }));
    await waitFor(() => screen.getByText(/đủ điều kiện xuất bản/i));
    expect(screen.getByRole("link", { name: /đi tới xuất bản/i })).toHaveAttribute(
      "href",
      `/lessons/${LESSON_ID}/publish`,
    );
  });

  it("invalidates the result when the draft revision changes", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.post(`*/api/proxy/admin/lessons/${LESSON_ID}/validate`, () =>
        HttpResponse.json({
          ready: true,
          errors: [],
          warnings: [],
          summary: { stageCount: 1, activityCount: 1, errorCount: 0, warningCount: 0 },
        }),
      ),
    );
    // Stateful harness — the builder bumps revision on every draft mutation.
    function Harness() {
      const [rev, setRev] = useState(1);
      return (
        <>
          <PublishReadinessCard lessonId={LESSON_ID} revision={rev} />
          <button onClick={() => setRev((r) => r + 1)}>edit draft</button>
        </>
      );
    }
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <Harness />
      </QueryClientProvider>,
    );
    await userEvent.click(screen.getByRole("button", { name: /kiểm tra xuất bản/i }));
    await waitFor(() => screen.getByText(/đủ điều kiện xuất bản/i));
    // Simulate a draft save — stale READY must disappear.
    await userEvent.click(screen.getByRole("button", { name: /edit draft/i }));
    await waitFor(() =>
      expect(screen.queryByText(/đủ điều kiện xuất bản/i)).not.toBeInTheDocument(),
    );
    // Editing must NOT be blocked — the check button is still available.
    expect(
      screen.getByRole("button", { name: /kiểm tra xuất bản/i }),
    ).toBeInTheDocument();
  });
});
