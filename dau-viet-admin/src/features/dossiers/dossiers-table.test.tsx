import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { describe, expect, it } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { DossiersTable } from "./dossiers-table";

function renderTable() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <DossiersTable />
    </QueryClientProvider>,
  );
}

describe("DossiersTable", () => {
  it("renders dossier rows with type labels and version", async () => {
    authStore.setAccessToken("t", 900);
    renderTable();
    await waitFor(() => expect(screen.getByText("Ngô Quyền")).toBeInTheDocument());
    expect(screen.getByText("Sông Bạch Đằng")).toBeInTheDocument();
    expect(screen.getByText("ngo-quyen")).toBeInTheDocument();
    expect(screen.getAllByText(/v\d/).length).toBeGreaterThan(0);
  });

  it("type filter sends the dossierType param to the backend", async () => {
    authStore.setAccessToken("t", 900);
    const captured: (string | null)[] = [];
    server.use(
      http.get("*/api/proxy/admin/dossiers", ({ request }) => {
        captured.push(new URL(request.url).searchParams.get("type"));
        return HttpResponse.json({
          content: [],
          page: 0,
          size: 20,
          totalElements: 0,
          totalPages: 0,
        });
      }),
    );
    renderTable();
    const selects = screen.getAllByRole("combobox");
    // Select dau tien = loai dossier (truoc status select).
    await userEvent.selectOptions(selects[0]!, "PERSON");
    await waitFor(() => expect(captured).toContain("PERSON"));
  });

  it("status filter sends the status param to the backend", async () => {
    authStore.setAccessToken("t", 900);
    const captured: (string | null)[] = [];
    server.use(
      http.get("*/api/proxy/admin/dossiers", ({ request }) => {
        captured.push(new URL(request.url).searchParams.get("status"));
        return HttpResponse.json({
          content: [],
          page: 0,
          size: 20,
          totalElements: 0,
          totalPages: 0,
        });
      }),
    );
    renderTable();
    const selects = screen.getAllByRole("combobox");
    await userEvent.selectOptions(selects[1]!, "PUBLISHED");
    await waitFor(() => expect(captured).toContain("PUBLISHED"));
  });
});
