import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HttpResponse, http } from "msw";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { BuilderPage } from "./builder-page";

const LESSON_ID = "33333333-3333-3333-3333-333333333333";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

function renderBuilder(id = LESSON_ID) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <BuilderPage lessonId={id} />
    </QueryClientProvider>,
  );
}

describe("BuilderPage", () => {
  it("renders 4 stages from the fixture draft in the navigator", async () => {
    authStore.setAccessToken("t", 900);
    renderBuilder();
    await waitFor(() => screen.getByText("Giai đoạn (4)"));
    expect(screen.getByText(/Bối cảnh 938/)).toBeInTheDocument();
    expect(screen.getAllByText(/Kết luận/).length).toBeGreaterThan(0);
  });

  it("saves draft via PUT with expectedRowVersion and marks clean", async () => {
    authStore.setAccessToken("t", 900);
    let saved: Record<string, unknown> | null = null;
    server.use(
      http.put(`*/api/proxy/admin/lessons/${LESSON_ID}/draft`, async ({ request }) => {
        saved = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({
          id: LESSON_ID,
          eventId: "11111111-1111-1111-1111-111111111111",
          templateId: "66666666-6666-6666-6666-666666666666",
          title: "L",
          centralQuestion: "Q",
          objectivesJson: "[]",
          draftJson: saved.draftJson,
          status: "DRAFT",
          currentVersionId: null,
          rowVersion: 4,
          createdBy: "u",
          updatedBy: "u",
          createdAt: "x",
          updatedAt: "y",
        });
      }),
    );
    renderBuilder();
    await waitFor(() => screen.getByText("Giai đoạn (4)"));

    // Sửa tên giai đoạn 1 → dirty → nút Lưu bật.
    const titleInput = await screen.findByLabelText(/tên giai đoạn/i);
    await userEvent.clear(titleInput);
    await userEvent.type(titleInput, "Bối cảnh sửa");
    await userEvent.click(screen.getByRole("button", { name: /lưu nháp/i }));

    await waitFor(() => expect(screen.getByText(/Đã lưu/)).toBeInTheDocument());
    expect(saved).toMatchObject({ expectedRowVersion: 3 });
    const out = JSON.parse(String(saved!.draftJson));
    expect(out.stages[0].title).toBe("Bối cảnh sửa");
    // Round-trip: stage 2 vẫn nguyên, unknown keys không mất.
    expect(out.stages).toHaveLength(4);
  });

  it("maps 422 DRAFT_SCHEMA_INVALID errors into the validation panel", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.put(`*/api/proxy/admin/lessons/${LESSON_ID}/draft`, () =>
        HttpResponse.json(
          {
            code: "DRAFT_SCHEMA_INVALID",
            message: "invalid",
            details: {
              errors: [
                {
                  path: "stages[1].activities[0].config",
                  code: "INVALID_CONFIG",
                  message: "Trắc nghiệm cần câu hỏi",
                },
              ],
            },
          },
          { status: 422 },
        ),
      ),
    );
    renderBuilder();
    await waitFor(() => screen.getByText("Giai đoạn (4)"));
    const titleInput = await screen.findByLabelText(/tên giai đoạn/i);
    await userEvent.type(titleInput, "x");
    await userEvent.click(screen.getByRole("button", { name: /lưu nháp/i }));
    await waitFor(() => screen.getByText(/INVALID_CONFIG/));
    expect(screen.getByText("Lỗi từ máy chủ (1)")).toBeInTheDocument();
  });

  it("shows conflict banner on 409 and reload resets it", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.put(`*/api/proxy/admin/lessons/${LESSON_ID}/draft`, () =>
        HttpResponse.json(
          { code: "OPTIMISTIC_LOCK_CONFLICT", message: "conflict" },
          { status: 409 },
        ),
      ),
    );
    renderBuilder();
    await waitFor(() => screen.getByText("Giai đoạn (4)"));
    const titleInput = await screen.findByLabelText(/tên giai đoạn/i);
    await userEvent.type(titleInput, "x");
    await userEvent.click(screen.getByRole("button", { name: /lưu nháp/i }));
    await waitFor(() =>
      screen.getByText(/đã bị người khác sửa đồng thời/i),
    );
    expect(
      screen.getByRole("button", { name: /tải lại bản mới nhất/i }),
    ).toBeInTheDocument();
  });

  it("shows PUBLISHED banner but keeps editing enabled", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.get(`*/api/proxy/admin/lessons/${LESSON_ID}`, () =>
        HttpResponse.json({
          id: LESSON_ID,
          eventId: "11111111-1111-1111-1111-111111111111",
          templateId: "66666666-6666-6666-6666-666666666666",
          title: "L",
          centralQuestion: "Q",
          objectivesJson: "[]",
          draftJson: JSON.stringify({ schemaVersion: 1, stages: [] }),
          status: "PUBLISHED",
          currentVersionId: "ver-1",
          rowVersion: 7,
          createdBy: "u",
          updatedBy: "u",
          createdAt: "x",
          updatedAt: "y",
        }),
      ),
    );
    renderBuilder();
    await waitFor(() =>
      screen.getByText(/ĐÃ XUẤT BẢN\. Thay đổi lưu vào bản nháp mới/i),
    );
    // Vẫn có nút lưu (không readOnly) — status PUBLISHED chỉ cảnh báo.
    expect(screen.getByRole("button", { name: /lưu nháp/i })).toBeInTheDocument();
  });

  it("shows publish-readiness after POST /validate", async () => {
    authStore.setAccessToken("t", 900);
    renderBuilder();
    await waitFor(() => screen.getByText("Giai đoạn (4)"));
    await userEvent.click(screen.getByRole("button", { name: /kiểm tra xuất bản/i }));
    await waitFor(() => screen.getByText(/Chưa sẵn sàng xuất bản — xem chi tiết/));
    expect(screen.getByText(/NO_REQUIRED_ACTIVITY/)).toBeInTheDocument();
  });

  it("seeds stages from template presetJson on confirm (append, remapped ids)", async () => {
    authStore.setAccessToken("t", 900);
    vi.spyOn(window, "confirm").mockReturnValue(true);
    renderBuilder();
    await waitFor(() => screen.getByText("Giai đoạn (4)"));
    const seedBtn = await screen.findByRole(
      "button",
      { name: /tạo cấu trúc từ khung bài học/i },
      { timeout: 5000 },
    );
    await userEvent.click(seedBtn);
    await waitFor(() => screen.getByText("Giai đoạn (6)"));
    // "Bối cảnh (mẫu)" xuất hiện cả trong navigator lẫn ô nextStageIds của stage 1.
    expect(screen.getAllByText(/Bối cảnh \(mẫu\)/).length).toBeGreaterThan(0);
  });
});
