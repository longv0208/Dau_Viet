import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { describe, expect, it } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { ReconcilePanel } from "./reconcile-panel";

function renderPanel() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <ReconcilePanel />
    </QueryClientProvider>,
  );
}

describe("ReconcilePanel", () => {
  it("confirm dialog opens then POSTs reconcile with batchSize", async () => {
    authStore.setAccessToken("t", 900);
    let called = false;
    server.use(
      http.post("*/api/proxy/admin/rewards/reconcile-unlocks", ({ request }) => {
        called = true;
        expect(new URL(request.url).searchParams.get("batchSize")).toBe("200");
        return HttpResponse.json({ itemsGranted: 4, usersScanned: 120, batches: 1 });
      }),
    );
    renderPanel();
    await userEvent.click(
      screen.getByRole("button", { name: /đối soát vật phẩm chưa nhận/i }),
    );
    // ConfirmDialog phai mo — backend chi chay khi admin xac nhan.
    await waitFor(() =>
      expect(screen.getByText(/chạy đối soát vật phẩm/i)).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByRole("button", { name: "Chạy đối soát" }));
    await waitFor(() => expect(called).toBe(true));
  });

  it("result card renders the real counters from the response", async () => {
    authStore.setAccessToken("t", 900);
    renderPanel();
    await userEvent.click(
      screen.getByRole("button", { name: /đối soát vật phẩm chưa nhận/i }),
    );
    await waitFor(() =>
      expect(screen.getByText(/chạy đối soát vật phẩm/i)).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByRole("button", { name: "Chạy đối soát" }));
    await waitFor(() => expect(screen.getByText("120")).toBeInTheDocument());
    expect(screen.getByText("4")).toBeInTheDocument();
    expect(screen.getByText("Vật phẩm đã cấp")).toBeInTheDocument();
    expect(screen.getByText("Học viên đã quét")).toBeInTheDocument();
    expect(screen.getByText("Số batch")).toBeInTheDocument();
  });
});
