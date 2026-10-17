import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import { HttpResponse, http } from "msw";
import { describe, expect, it } from "vitest";

import { server } from "@/test/msw/server";
import { emptyPageFixture, evidencesPageFixture } from "@/test/fixtures";
import { authStore } from "@/features/auth/auth-store";

import { EvidenceTable } from "./evidence-table";

function renderTable() {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <EvidenceTable />
    </QueryClientProvider>,
  );
}

describe("EvidenceTable", () => {
  it("renders rows from the real contract and marks incomplete sources", async () => {
    authStore.setAccessToken("test-access-token", 900);
    // Force a row with empty sourceTitle to exercise the "Chưa đủ nguồn" badge.
    server.use(
      http.get("*/api/proxy/admin/evidences", () =>
        HttpResponse.json({
          ...emptyPageFixture,
          totalElements: 2,
          totalPages: 1,
          content: [
            evidencesPageFixture.content[0],
            { ...evidencesPageFixture.content[1], sourceTitle: "" },
          ],
        }),
      ),
    );
    renderTable();
    await waitFor(() => {
      expect(screen.getByText("Cọc ngầm sông Bạch Đằng")).toBeInTheDocument();
      expect(
        screen.getByText("Đại Việt sử ký toàn thư — trận Bạch Đằng"),
      ).toBeInTheDocument();
    });
    // StatusChip + filter <option> both carry these labels — allow multiples.
    expect(screen.getAllByText("Đã phê duyệt").length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText("Bản nháp").length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText("Chưa đủ nguồn")).toBeInTheDocument();
  });

  it("shows error state on 500", async () => {
    authStore.setAccessToken("test-access-token", 900);
    server.use(
      http.get("*/api/proxy/admin/evidences", () =>
        HttpResponse.json({ code: "INTERNAL", message: "boom" }, { status: 500 }),
      ),
    );
    renderTable();
    await waitFor(() => expect(screen.getByText("Có lỗi xảy ra")).toBeInTheDocument());
  });

  it("shows empty state when the list is empty", async () => {
    authStore.setAccessToken("test-access-token", 900);
    server.use(
      http.get("*/api/proxy/admin/evidences", () =>
        HttpResponse.json(emptyPageFixture),
      ),
    );
    renderTable();
    await waitFor(() =>
      expect(screen.getByText("Chưa có bằng chứng nào")).toBeInTheDocument(),
    );
  });
});
