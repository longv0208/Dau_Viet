import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HttpResponse, http } from "msw";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { PublishPage } from "./publish-page";

const LESSON_ID = "33333333-3333-3333-3333-333333333333";
const DRAFT_LESSON = "55555555-5555-5555-5555-555555555555";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
}));

function renderPage(id = LESSON_ID) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <PublishPage lessonId={id} />
    </QueryClientProvider>,
  );
}

describe("PublishPage", () => {
  it("publishes a DRAFT lesson and shows versionNo + publishedAt", async () => {
    authStore.setAccessToken("t", 900);
    vi.spyOn(window, "confirm").mockReturnValue(true);
    renderPage(DRAFT_LESSON);
    await waitFor(() => screen.getByText("Bài học nháp chưa xuất bản"));

    await userEvent.click(screen.getByRole("button", { name: /xuất bản bài học/i }));
    // Confirm dialog → confirm.
    await waitFor(() => screen.getByText(/Xuất bản bài học này\?/));
    await userEvent.click(screen.getByRole("button", { name: /^Xuất bản$/ }));

    await waitFor(() => screen.getByText(/Đã xuất bản phiên bản 1 thành công/i));
    expect(screen.getByText(/v-55555555/)).toBeInTheDocument();
  });

  it("maps 422 EVENT_NOT_PUBLISHED to a VN message + link to the event", async () => {
    authStore.setAccessToken("t", 900);
    vi.spyOn(window, "confirm").mockReturnValue(true);
    server.use(
      http.post(`*/api/proxy/admin/lessons/${DRAFT_LESSON}/publish`, () =>
        HttpResponse.json(
          {
            code: "DRAFT_SCHEMA_INVALID",
            message: "not ready",
            details: {
              errors: [
                {
                  path: "eventId",
                  code: "EVENT_NOT_PUBLISHED",
                  message: "Sự kiện lịch sử chưa được xuất bản",
                },
              ],
            },
          },
          { status: 422 },
        ),
      ),
    );
    renderPage(DRAFT_LESSON);
    await waitFor(() => screen.getByText("Bài học nháp chưa xuất bản"));
    await userEvent.click(screen.getByRole("button", { name: /xuất bản bài học/i }));
    await waitFor(() => screen.getByText(/Xuất bản bài học này\?/));
    await userEvent.click(screen.getByRole("button", { name: /^Xuất bản$/ }));

    await waitFor(() =>
      screen.getAllByText(/Sự kiện lịch sử chưa được xuất bản/i).length > 0,
    );
    expect(
      screen.getByRole("link", { name: /đi tới trang sự kiện/i }),
    ).toHaveAttribute("href", "/events/22222222-2222-2222-2222-222222222222");
    expect(screen.getByRole("link", { name: /đi tới chỉnh sửa/i })).toHaveAttribute(
      "href",
      `/lessons/${DRAFT_LESSON}/builder`,
    );
  });

  it("409 conflict shows reload prompt", async () => {
    authStore.setAccessToken("t", 900);
    vi.spyOn(window, "confirm").mockReturnValue(true);
    server.use(
      http.post(`*/api/proxy/admin/lessons/${DRAFT_LESSON}/publish`, () =>
        HttpResponse.json(
          { code: "OPTIMISTIC_LOCK_CONFLICT", message: "conflict" },
          { status: 409 },
        ),
      ),
    );
    renderPage(DRAFT_LESSON);
    await waitFor(() => screen.getByText("Bài học nháp chưa xuất bản"));
    await userEvent.click(screen.getByRole("button", { name: /xuất bản bài học/i }));
    await waitFor(() => screen.getByText(/Xuất bản bài học này\?/));
    await userEvent.click(screen.getByRole("button", { name: /^Xuất bản$/ }));

    await waitFor(() => screen.getByText(/đã bị sửa đồng thời/i));
    expect(screen.getByRole("button", { name: /tải lại bản mới nhất/i })).toBeInTheDocument();
  });

  it("learner verify card fetches /lessons/{id}/content and shows versionNo", async () => {
    authStore.setAccessToken("t", 900);
    renderPage(LESSON_ID); // fixture: PUBLISHED + currentVersionId
    await waitFor(() => screen.getByRole("button", { name: /kiểm tra nội dung learner/i }));
    await userEvent.click(screen.getByRole("button", { name: /kiểm tra nội dung learner/i }));
    await waitFor(() => screen.getByText(/Phiên bản 1 đang phát hành/i));
  });
});
