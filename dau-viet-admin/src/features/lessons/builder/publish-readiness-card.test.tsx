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
  dirty?: boolean;
  saving?: boolean;
  onJump?: (s: string | null, a: string | null) => void;
}) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <PublishReadinessCard
        lessonId={LESSON_ID}
        draft={props?.draft}
        revision={props?.revision}
        dirty={props?.dirty}
        saving={props?.saving}
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
    await waitFor(() => screen.getByText(/chưa sẵn sàng xuất bản/i));
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
    // NO_REQUIRED_ACTIVITY renders as its CODE_MESSAGES Vietnamese text.
    const errItem = screen
      .getByText(/Cần ít nhất một hoạt động bắt buộc/)
      .closest("button");
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

  it("blocks validation while dirty and clears stale READY after save", async () => {
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
    // Stateful harness mirroring the builder: edit bumps revision + sets dirty;
    // save clears dirty without touching revision (markSaved semantics).
    function Harness() {
      const [rev, setRev] = useState(1);
      const [dirty, setDirty] = useState(false);
      return (
        <>
          <PublishReadinessCard lessonId={LESSON_ID} revision={rev} dirty={dirty} />
          <button
            onClick={() => {
              setRev((r) => r + 1);
              setDirty(true);
            }}
          >
            edit
          </button>
          <button onClick={() => setDirty(false)}>save</button>
        </>
      );
    }
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <Harness />
      </QueryClientProvider>,
    );

    // 1) Validate the saved draft → READY shows.
    await userEvent.click(screen.getByRole("button", { name: /kiểm tra xuất bản/i }));
    await waitFor(() => screen.getByText(/đủ điều kiện xuất bản/i));

    // 2) Edit → dirty; validation is now blocked with a clear label.
    await userEvent.click(screen.getByRole("button", { name: /^edit$/i }));
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: /kiểm tra xuất bản \(cần lưu trước\)/i }),
      ).toBeDisabled(),
    );
    // Old READY must not be presented as applying to the unsaved content.
    expect(screen.queryByText(/đủ điều kiện xuất bản/i)).not.toBeInTheDocument();

    // 3) Save → button re-enables; validate again against the new saved draft.
    await userEvent.click(screen.getByRole("button", { name: /^save$/i }));
    await userEvent.click(screen.getByRole("button", { name: /kiểm tra xuất bản/i }));
    await waitFor(() => screen.getByText(/đủ điều kiện xuất bản/i));
  });
});
