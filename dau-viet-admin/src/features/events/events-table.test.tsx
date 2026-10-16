import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import { HttpResponse, http } from "msw";
import { describe, expect, it } from "vitest";

import { server } from "@/test/msw/server";
import { emptyPageFixture } from "@/test/fixtures";
import { authStore } from "@/features/auth/auth-store";

import { EventsTable } from "./events-table";

function renderTable() {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <EventsTable />
    </QueryClientProvider>,
  );
}

describe("EventsTable", () => {
  it("renders rows from the real contract", async () => {
    authStore.setAccessToken("test-access-token", 900);
    renderTable();
    await waitFor(() => {
      expect(screen.getByText("Trận Bạch Đằng 938")).toBeInTheDocument();
      expect(screen.getByText("Chiến thắng Điện Biên Phủ")).toBeInTheDocument();
    });
    expect(screen.getByText("Đã xuất bản")).toBeInTheDocument();
    expect(screen.getByText("Bản nháp")).toBeInTheDocument();
  });

  it("shows error state on 500", async () => {
    authStore.setAccessToken("test-access-token", 900);
    server.use(
      http.get("*/api/proxy/admin/events", () =>
        HttpResponse.json({ code: "INTERNAL", message: "boom" }, { status: 500 }),
      ),
    );
    renderTable();
    await waitFor(() => expect(screen.getByText("Có lỗi xảy ra")).toBeInTheDocument());
  });

  it("shows empty state when the list is empty", async () => {
    authStore.setAccessToken("test-access-token", 900);
    server.use(
      http.get("*/api/proxy/admin/events", () => HttpResponse.json(emptyPageFixture)),
    );
    renderTable();
    await waitFor(() =>
      expect(screen.getByText("Chưa có sự kiện nào")).toBeInTheDocument(),
    );
  });
});
