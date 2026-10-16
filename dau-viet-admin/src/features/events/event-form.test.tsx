import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HttpResponse, http } from "msw";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { EventForm } from "./event-form";

const pushMock = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock, replace: vi.fn() }),
}));

function renderForm(initial?: Parameters<typeof EventForm>[0]["initial"]) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <EventForm initial={initial} />
    </QueryClientProvider>,
  );
}

describe("EventForm", () => {
  it("shows Vietnamese validation errors on empty submit", async () => {
    authStore.setAccessToken("t", 900);
    renderForm();
    await userEvent.click(screen.getByRole("button", { name: /tạo sự kiện/i }));
    await waitFor(() => {
      expect(screen.getByText("Vui lòng nhập tiêu đề")).toBeInTheDocument();
      expect(screen.getByText("Vui lòng nhập tóm tắt")).toBeInTheDocument();
    });
  });

  it("auto-suggests a kebab-case slug from the title", async () => {
    authStore.setAccessToken("t", 900);
    renderForm();
    await userEvent.type(screen.getByLabelText(/tiêu đề/i), "Trận Bạch Đằng 938");
    await waitFor(() =>
      expect(screen.getByLabelText(/slug/i)).toHaveValue("tran-bach-dang-938"),
    );
  });

  it("creates an event and navigates to its editor", async () => {
    authStore.setAccessToken("t", 900);
    let posted: Record<string, unknown> | null = null;
    server.use(
      http.post("*/api/proxy/admin/events", async ({ request }) => {
        posted = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ id: "evt-new", ...posted }, { status: 201 });
      }),
    );
    renderForm();
    await userEvent.type(screen.getByLabelText(/tiêu đề/i), "Trận Bạch Đằng 938");
    await userEvent.type(screen.getByLabelText(/năm bắt đầu/i), "938");
    await userEvent.type(screen.getByLabelText(/tóm tắt/i), "Chiến thắng lịch sử");
    await userEvent.click(screen.getByRole("button", { name: /tạo sự kiện/i }));
    await waitFor(() => expect(pushMock).toHaveBeenCalledWith("/events/evt-new"));
    expect(posted).toMatchObject({
      title: "Trận Bạch Đằng 938",
      slug: "tran-bach-dang-938",
      summary: "Chiến thắng lịch sử",
    });
    // Contract: startYear goes over the wire as a number, not a string.
    expect(posted!.startYear).toBe(938);
  });

  it("maps a backend VALIDATION_ERROR onto the slug field", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.post("*/api/proxy/admin/events", () =>
        HttpResponse.json(
          {
            code: "VALIDATION_ERROR",
            message: "Validation failed",
            details: { slug: "slug must be lowercase kebab-case" },
          },
          { status: 400 },
        ),
      ),
    );
    renderForm();
    await userEvent.type(screen.getByLabelText(/tiêu đề/i), "X");
    await userEvent.type(screen.getByLabelText(/tóm tắt/i), "Y");
    await userEvent.click(screen.getByRole("button", { name: /tạo sự kiện/i }));
    await waitFor(() =>
      expect(screen.getByText("slug must be lowercase kebab-case")).toBeInTheDocument(),
    );
  });

  it("edits an existing event with expectedRowVersion", async () => {
    authStore.setAccessToken("t", 900);
    let patched: Record<string, unknown> | null = null;
    server.use(
      http.patch("*/api/proxy/admin/events/evt-1", async ({ request }) => {
        patched = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({
          id: "evt-1",
          ...patched,
          status: "DRAFT",
          rowVersion: 2,
          createdAt: "2026-01-01T00:00:00Z",
          updatedAt: "2026-01-02T00:00:00Z",
        });
      }),
    );
    renderForm({
      id: "evt-1",
      slug: "old",
      title: "Old title",
      era: null,
      period: null,
      startYear: null,
      summary: "old sum",
      description: null,
      location: null,
      coverAssetKey: null,
      tags: [],
      status: "DRAFT",
      rowVersion: 1,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
    });
    const titleInput = screen.getByLabelText(/tiêu đề/i);
    await userEvent.clear(titleInput);
    await userEvent.type(titleInput, "New title");
    await userEvent.click(screen.getByRole("button", { name: /lưu thay đổi/i }));
    await waitFor(() => expect(screen.getByText("Đã lưu thay đổi.")).toBeInTheDocument());
    expect(patched).toMatchObject({ title: "New title", expectedRowVersion: 1 });
  });
});
