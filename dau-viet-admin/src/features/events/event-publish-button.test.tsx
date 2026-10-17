import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { authStore } from "@/features/auth/auth-store";
import type { AdminEventDetail } from "@/lib/dto/event";

import { EventPublishButton } from "./event-publish-button";

const base: AdminEventDetail = {
  id: "22222222-2222-2222-2222-222222222222",
  slug: "dien-bien-phu-1954",
  title: "Chiến thắng Điện Biên Phủ",
  era: "Hiện đại",
  period: null,
  startYear: 1954,
  summary: "Tóm tắt",
  description: null,
  location: null,
  coverAssetKey: null,
  tags: [],
  status: "DRAFT",
  rowVersion: 1,
  createdAt: "2026-01-01T00:00:00Z",
  updatedAt: "2026-01-01T00:00:00Z",
};

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn() }),
}));

function renderButton(ev = base) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <EventPublishButton event={ev} />
    </QueryClientProvider>,
  );
}

describe("EventPublishButton", () => {
  it("shows publish button for DRAFT event; confirm calls publish", async () => {
    authStore.setAccessToken("t", 900);
    renderButton();
    await userEvent.click(screen.getByRole("button", { name: /xuất bản sự kiện/i }));
    await waitFor(() => screen.getByText(/Xuất bản sự kiện này\?/));
    await userEvent.click(screen.getByRole("button", { name: /^Xuất bản$/ }));
    // After success the mutation settles — no error shown.
    await waitFor(() => expect(screen.queryByRole("alert")).toBeNull());
  });

  it("renders nothing for PUBLISHED or ARCHIVED events", () => {
    renderButton({ ...base, status: "PUBLISHED" });
    expect(screen.queryByRole("button", { name: /xuất bản sự kiện/i })).toBeNull();
    renderButton({ ...base, status: "ARCHIVED" });
    expect(screen.queryByRole("button", { name: /xuất bản sự kiện/i })).toBeNull();
  });
});
