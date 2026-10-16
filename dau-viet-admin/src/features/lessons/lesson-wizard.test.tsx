import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HttpResponse, http } from "msw";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { LessonWizard } from "./lesson-wizard";

const pushMock = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock, replace: vi.fn() }),
  useSearchParams: () => new URLSearchParams(),
}));

function renderWizard() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <LessonWizard />
    </QueryClientProvider>,
  );
}

async function goThroughSteps() {
  // Step 1: pick the first event.
  await waitFor(() => screen.getByText("Trận Bạch Đằng 938"));
  await userEvent.click(screen.getByText("Trận Bạch Đằng 938"));
  await userEvent.click(screen.getByRole("button", { name: /tiếp tục/i }));
  // Step 2: pick the template.
  await waitFor(() => screen.getByText("Điều tra sự kiện"));
  await userEvent.click(screen.getByText("Điều tra sự kiện"));
  await userEvent.click(screen.getByRole("button", { name: /tiếp tục/i }));
}

describe("LessonWizard", () => {
  it("walks all 4 steps and posts a draft to the backend", async () => {
    authStore.setAccessToken("t", 900);
    let posted: Record<string, unknown> | null = null;
    server.use(
      http.post("*/api/proxy/admin/lessons", async ({ request }) => {
        posted = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ id: "lesson-new", ...posted }, { status: 201 });
      }),
    );
    renderWizard();
    await goThroughSteps();
    // Step 3 basic info.
    await userEvent.type(screen.getByLabelText(/tiêu đề bài học/i), "Bí mật Bạch Đằng");
    await userEvent.type(
      screen.getByLabelText(/câu hỏi trung tâm/i),
      "Vì sao Ngô Quyền thắng?",
    );
    await userEvent.type(screen.getByPlaceholderText("Mục tiêu 1"), "Hiểu bối cảnh");
    await userEvent.click(screen.getByRole("button", { name: /tiếp tục/i }));
    // Step 4 confirm.
    await waitFor(() => screen.getByText("Lưu bản nháp"));
    await userEvent.click(screen.getByRole("button", { name: /lưu bản nháp/i }));
    await waitFor(() => expect(pushMock).toHaveBeenCalledWith("/lessons/lesson-new"));
    expect(posted).toMatchObject({
      title: "Bí mật Bạch Đằng",
      centralQuestion: "Vì sao Ngô Quyền thắng?",
      draftJson: "{}",
    });
    expect(JSON.parse(posted!.objectivesJson as string)).toEqual(["Hiểu bối cảnh"]);
  });

  it("blocks step 3 submit until required fields are filled", async () => {
    authStore.setAccessToken("t", 900);
    renderWizard();
    await goThroughSteps();
    await userEvent.click(screen.getByRole("button", { name: /tiếp tục/i }));
    await waitFor(() => {
      expect(screen.getByText("Vui lòng nhập tiêu đề bài học")).toBeInTheDocument();
      expect(screen.getByText("Vui lòng nhập câu hỏi trung tâm")).toBeInTheDocument();
    });
  });

  it("shows a friendly empty state when no events exist", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.get("*/api/proxy/admin/events", () =>
        HttpResponse.json({ content: [], page: 0, size: 20, totalElements: 0, totalPages: 0 }),
      ),
    );
    renderWizard();
    await waitFor(() =>
      expect(screen.getByText("Chưa có sự kiện nào")).toBeInTheDocument(),
    );
    expect(screen.getByRole("link", { name: /tạo sự kiện đầu tiên/i })).toBeInTheDocument();
  });
});
