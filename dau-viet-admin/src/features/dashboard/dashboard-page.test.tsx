import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import { HttpResponse, http } from "msw";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { DashboardPage } from "./dashboard-page";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace: vi.fn(), push: vi.fn() }),
}));

function renderPage() {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <DashboardPage />
    </QueryClientProvider>,
  );
}

describe("DashboardPage (A-02)", () => {
  it("renders welcome, ping status and quick nav", async () => {
    authStore.setAccessToken("test-access-token", 900);
    renderPage();
    await waitFor(() =>
      expect(screen.getByText(/Xin chào, Quản trị viên/)).toBeInTheDocument(),
    );
    await waitFor(() =>
      expect(screen.getByText("Backend: Hoạt động")).toBeInTheDocument(),
    );
    expect(screen.getByText("Truy cập nhanh")).toBeInTheDocument();
    expect(screen.getByText("Bài học gần đây")).toBeInTheDocument();
  });

  it("shows backend error + traceId when ping fails", async () => {
    authStore.setAccessToken("test-access-token", 900);
    server.use(
      http.get("*/api/proxy/admin/ping", () =>
        HttpResponse.json(
          { code: "FORBIDDEN", message: "no", traceId: "trace-abc" },
          { status: 403 },
        ),
      ),
    );
    renderPage();
    await waitFor(() =>
      expect(screen.getByText("Backend: Lỗi")).toBeInTheDocument(),
    );
    expect(screen.getByText(/trace-abc/)).toBeInTheDocument();
  });
});
