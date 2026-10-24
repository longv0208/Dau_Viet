import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import { HttpResponse, http } from "msw";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";
import { lessonsPageFixture } from "@/test/fixtures";
import { authStore } from "@/features/auth/auth-store";

import { EventWorkspacePage } from "./event-workspace-page";

const EVENT_ID = "11111111-1111-1111-1111-111111111111";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
  useSearchParams: () => new URLSearchParams(),
  usePathname: () => `/events/${EVENT_ID}`,
}));

function renderWorkspace(tab: Parameters<typeof EventWorkspacePage>[0]["tab"] = "overview") {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <EventWorkspacePage eventId={EVENT_ID} tab={tab} />
    </QueryClientProvider>,
  );
}

describe("EventWorkspacePage", () => {
  it("loads the event and renders the workspace header + tab nav", async () => {
    authStore.setAccessToken("t", 900);
    renderWorkspace();
    await waitFor(() =>
      expect(
        screen.getByRole("heading", { name: "Trận Bạch Đằng 938" }),
      ).toBeInTheDocument(),
    );
    for (const label of ["Tổng quan", "Bài học", "Học liệu", "Thông tin & địa điểm"]) {
      expect(screen.getByRole("link", { name: label })).toBeInTheDocument();
    }
  });

  it("shows the error state when the event cannot be loaded", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.get(`*/api/proxy/admin/events/${EVENT_ID}`, () =>
        HttpResponse.json({ code: "INTERNAL", message: "boom" }, { status: 500 }),
      ),
    );
    renderWorkspace();
    await waitFor(() => expect(screen.getByText("Có lỗi xảy ra")).toBeInTheDocument());
  });

  it("overview tab shows real counts from list endpoints (no mock numbers)", async () => {
    authStore.setAccessToken("t", 900);
    const lessonsOfEvent = lessonsPageFixture.content.filter((l) => l.eventId === EVENT_ID);
    server.use(
      http.get("*/api/proxy/admin/lessons", ({ request }) => {
        const url = new URL(request.url);
        const eventId = url.searchParams.get("eventId");
        const content = eventId ? lessonsOfEvent : lessonsPageFixture.content;
        return HttpResponse.json({
          ...lessonsPageFixture,
          content,
          totalElements: content.length,
        });
      }),
      http.get("*/api/proxy/admin/animation-scenes", ({ request }) => {
        const url = new URL(request.url);
        const eventId = url.searchParams.get("eventId");
        return HttpResponse.json({
          content: [],
          page: 0,
          size: 20,
          totalElements: eventId === EVENT_ID ? 0 : 4,
          totalPages: 0,
        });
      }),
    );
    renderWorkspace();
    // 1 lesson + 2 evidences for this event in the fixtures.
    await waitFor(() =>
      expect(screen.getByText("Vì sao Ngô Quyền thắng trận Bạch Đằng?")).toBeInTheDocument(),
    );
    // Stat cards: label → closest link shows the real total from the API.
    const evidenceCard = screen.getByText("Bằng chứng").closest("a");
    expect(evidenceCard).toHaveTextContent("2");
    const lessonCard = screen
      .getAllByText("Bài học", { selector: "p" })
      .map((el) => el.closest("a"))
      .find((a) => (a?.getAttribute("href") ?? "").includes("tab=lessons"));
    expect(lessonCard).toHaveTextContent("1");
  });

  it("lessons tab renders only the lessons of this event", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.get("*/api/proxy/admin/lessons", ({ request }) => {
        const url = new URL(request.url);
        const eventId = url.searchParams.get("eventId");
        const content = eventId
          ? lessonsPageFixture.content.filter((l) => l.eventId === eventId)
          : lessonsPageFixture.content;
        return HttpResponse.json({ ...lessonsPageFixture, content, totalElements: content.length });
      }),
    );
    renderWorkspace("lessons");
    await waitFor(() =>
      expect(screen.getByText("Vì sao Ngô Quyền thắng trận Bạch Đằng?")).toBeInTheDocument(),
    );
    // Lesson of the OTHER event must not appear.
    expect(screen.queryByText("Bài học nháp chưa xuất bản")).not.toBeInTheDocument();
    // The "Sự kiện" column + event filter are hidden in locked mode.
    expect(screen.queryByRole("columnheader", { name: "Sự kiện" })).not.toBeInTheDocument();
    expect(screen.queryByLabelText("Lọc theo sự kiện")).not.toBeInTheDocument();
  });

  it("hoc-lieu tab scopes the evidence table to this event", async () => {
    authStore.setAccessToken("t", 900);
    renderWorkspace("hoc-lieu");
    await waitFor(() =>
      expect(screen.getByText("Cọc ngầm sông Bạch Đằng")).toBeInTheDocument(),
    );
    expect(screen.getByText("Bằng chứng lịch sử")).toBeInTheDocument();
    expect(screen.getByText("Hình ảnh / Media")).toBeInTheDocument();
    expect(screen.getByText("Hoạt họa HTML")).toBeInTheDocument();
  });
});
