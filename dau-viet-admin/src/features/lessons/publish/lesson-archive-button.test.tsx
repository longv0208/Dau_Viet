import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { authStore } from "@/features/auth/auth-store";
import type { AdminLessonDetail } from "@/lib/dto/lesson";

import { LessonArchiveButton } from "./lesson-archive-button";

const base: AdminLessonDetail = {
  id: "33333333-3333-3333-3333-333333333333",
  eventId: "11111111-1111-1111-1111-111111111111",
  templateId: "t-1",
  title: "Vì sao Ngô Quyền thắng trận Bạch Đằng?",
  centralQuestion: "Vì sao?",
  objectivesJson: "[]",
  draftJson: "{}",
  status: "PUBLISHED",
  currentVersionId: "44444444-4444-4444-4444-444444444444",
  rowVersion: 3,
  createdBy: "admin",
  updatedBy: "admin",
  createdAt: "2026-01-01T00:00:00Z",
  updatedAt: "2026-01-01T00:00:00Z",
};

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
}));

function renderButton(lesson: AdminLessonDetail = base) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <LessonArchiveButton lesson={lesson} />
    </QueryClientProvider>,
  );
}

describe("LessonArchiveButton", () => {
  it("shows archive button for PUBLISHED lesson; confirm calls archive", async () => {
    authStore.setAccessToken("t", 900);
    renderButton();
    await userEvent.click(screen.getByRole("button", { name: /lưu trữ bài học/i }));
    await waitFor(() => screen.getByText(/Lưu trữ bài học này\?/));
    await userEvent.click(screen.getByRole("button", { name: /^Lưu trữ$/ }));
    await waitFor(() => expect(screen.queryByRole("alert")).toBeNull());
  });

  it("warns that learners lose access for PUBLISHED lessons", () => {
    renderButton();
    expect(
      screen.getByText(/Học viên sẽ không còn thấy bài học/i),
    ).toBeInTheDocument();
  });

  it("renders nothing for ARCHIVED lessons", () => {
    renderButton({ ...base, status: "ARCHIVED" });
    expect(screen.queryByRole("button", { name: /lưu trữ bài học/i })).toBeNull();
  });
});
