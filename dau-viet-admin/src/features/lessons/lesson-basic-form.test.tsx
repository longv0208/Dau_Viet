import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HttpResponse, http } from "msw";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { LessonBasicEditor } from "./lesson-basic-form";

const pushMock = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock, replace: vi.fn() }),
}));

function renderEditor(id = "33333333-3333-3333-3333-333333333333") {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <LessonBasicEditor lessonId={id} />
    </QueryClientProvider>,
  );
}

describe("LessonBasicEditor", () => {
  it("loads the lesson and shows its parsed objectives", async () => {
    authStore.setAccessToken("t", 900);
    renderEditor();
    await waitFor(() => {
      expect(screen.getByDisplayValue("Vì sao Ngô Quyền thắng trận Bạch Đằng?")).toBeInTheDocument();
      expect(screen.getByDisplayValue("Hiểu bối cảnh lịch sử")).toBeInTheDocument();
    });
    expect(screen.getByText("Đã xuất bản")).toBeInTheDocument();
  });

  it("PATCHes title/objectives with expectedRowVersion", async () => {
    authStore.setAccessToken("t", 900);
    let patched: Record<string, unknown> | null = null;
    server.use(
      http.patch("*/api/proxy/admin/lessons/33333333-3333-3333-3333-333333333333", async ({ request }) => {
        patched = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({
          id: "33333333-3333-3333-3333-333333333333",
          ...patched,
          rowVersion: 4,
          updatedAt: "2026-01-02T00:00:00Z",
        });
      }),
    );
    renderEditor();
    await waitFor(() => screen.getByDisplayValue("Vì sao Ngô Quyền thắng trận Bạch Đằng?"));
    const title = screen.getByLabelText(/tiêu đề \*/i);
    await userEvent.clear(title);
    await userEvent.type(title, "Tiêu đề mới");
    await userEvent.click(screen.getByRole("button", { name: /lưu thay đổi/i }));
    await waitFor(() => expect(screen.getByText("Đã lưu thay đổi.")).toBeInTheDocument());
    expect(patched).toMatchObject({ title: "Tiêu đề mới", expectedRowVersion: 3 });
  });

  it("shows OPTIMISTIC_LOCK_CONFLICT message on 409", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.patch("*/api/proxy/admin/lessons/33333333-3333-3333-3333-333333333333", () =>
        HttpResponse.json(
          { code: "OPTIMISTIC_LOCK_CONFLICT", message: "modified" },
          { status: 409 },
        ),
      ),
    );
    renderEditor();
    await waitFor(() => screen.getByDisplayValue("Vì sao Ngô Quyền thắng trận Bạch Đằng?"));
    const title = screen.getByLabelText(/tiêu đề \*/i);
    await userEvent.type(title, "x");
    await userEvent.click(screen.getByRole("button", { name: /lưu thay đổi/i }));
    await waitFor(() =>
      expect(screen.getByText(/sửa đồng thời/i)).toBeInTheDocument(),
    );
  });

  it("shows Sắp triển khai for the stage builder entry", async () => {
    authStore.setAccessToken("t", 900);
    renderEditor();
    await waitFor(() => screen.getByText("Sắp triển khai — Stage Builder sẽ có ở TASK tiếp theo."));
  });
});
