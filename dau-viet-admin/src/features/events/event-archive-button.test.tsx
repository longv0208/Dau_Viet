import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { authStore } from "@/features/auth/auth-store";
import type { AdminEventDetail } from "@/lib/dto/event";

import { EventArchiveButton } from "./event-archive-button";

const publishedWithLessons: AdminEventDetail = {
  id: "11111111-1111-1111-1111-111111111111",
  slug: "tran-bach-dang-938",
  title: "Trận Bạch Đằng 938",
  era: "Bắc thuộc lần 3",
  period: null,
  startYear: 938,
  summary: "Tóm tắt",
  description: null,
  location: null,
  coverAssetKey: null,
  tags: [],
  status: "PUBLISHED",
  rowVersion: 1,
  createdAt: "2026-01-01T00:00:00Z",
  updatedAt: "2026-01-01T00:00:00Z",
};

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
}));

function renderButton(ev: AdminEventDetail = publishedWithLessons) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <EventArchiveButton event={ev} />
    </QueryClientProvider>,
  );
}

describe("EventArchiveButton", () => {
  it("shows archive button; confirm calls archive (409 in-use shows friendly message)", async () => {
    authStore.setAccessToken("t", 900);
    renderButton();
    await userEvent.click(screen.getByRole("button", { name: /lưu trữ sự kiện/i }));
    await waitFor(() => screen.getByText(/Lưu trữ sự kiện này\?/));
    await userEvent.click(screen.getByRole("button", { name: /^Lưu trữ$/ }));
    // Event 11111111 còn bài học PUBLISHED → backend 409 EVENT_IN_USE.
    await waitFor(() =>
      screen.getByText(/còn bài học chưa lưu trữ/i),
    );
  });

  it("archives an event with no lessons — no error", async () => {
    authStore.setAccessToken("t", 900);
    renderButton({
      ...publishedWithLessons,
      id: "99999999-9999-9999-9999-999999999999",
      slug: "su-kien-khong-bai-hoc",
      status: "DRAFT",
    });
    await userEvent.click(screen.getByRole("button", { name: /lưu trữ sự kiện/i }));
    await waitFor(() => screen.getByText(/Lưu trữ sự kiện này\?/));
    await userEvent.click(screen.getByRole("button", { name: /^Lưu trữ$/ }));
    await waitFor(() => expect(screen.queryByRole("alert")).toBeNull());
  });

  it("renders nothing for ARCHIVED events", () => {
    renderButton({ ...publishedWithLessons, status: "ARCHIVED" });
    expect(screen.queryByRole("button", { name: /lưu trữ sự kiện/i })).toBeNull();
  });
});
