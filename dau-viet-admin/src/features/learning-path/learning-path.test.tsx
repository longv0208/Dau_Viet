import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { authStore } from "@/features/auth/auth-store";
import type { PathDetail } from "@/lib/dto/learning-path";

import { EventCatalog } from "./event-catalog";
import { EventPanel } from "./event-panel";
import { PathPreview } from "./path-preview";

const pathDetailFixture: PathDetail = {
  version: {
    id: "v-1",
    pathCode: "HISTORY_MAIN",
    versionNo: 1,
    title: "Hành trình Lịch sử Việt Nam",
    description: "Lộ trình chuẩn",
    status: "DRAFT",
    publishedAt: null,
    createdAt: "2026-01-01T00:00:00Z",
    updatedAt: "2026-01-01T00:00:00Z",
    revision: 1,
  },
  chapters: [
    {
      chapter: {
        id: "ch-1",
        code: "THOI-KY-1",
        title: "Buổi đầu độc lập",
        description: null,
        startYear: 938,
        endYear: 1009,
        periodLabel: "Thế kỷ X",
        sortOrder: 1,
        themeKey: "DEFAULT",
        nodeType: "PERIOD",
        parentId: null,
      },
      events: [
        {
          node: {
            id: "en-1",
            chapterId: "ch-1",
            eventId: "e-existing",
            sortOrder: 1,
            participationType: "REQUIRED",
          },
          title: "Trận Bạch Đằng 938",
          startYear: 938,
          contentStatus: "PLAYABLE",
          publishedPolicyId: "p-1",
          publishedPolicyVersion: 1,
          requiredLessonIds: ["l-1"],
          optionalLessonIds: [],
          lessons: [],
          eventStatus: "PUBLISHED",
          canonicalEventId: null,
          alias: false,
        },
      ],
    },
  ],
};

function wrap(ui: React.ReactElement) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={client}>{ui}</QueryClientProvider>);
}

describe("Learning Path — Default REQUIRED (Issue #47)", () => {
  it("EventCatalog adds events with participationType='REQUIRED'", async () => {
    authStore.setAccessToken("t", 900);
    const change = vi.fn().mockResolvedValue(pathDetailFixture);
    const onAdded = vi.fn();
    wrap(
      <EventCatalog
        detail={pathDetailFixture}
        chapterId="ch-1"
        disabled={false}
        change={change}
        onAdded={onAdded}
      />,
    );

    const addButtons = await screen.findAllByRole("button", { name: "Thêm" });
    await userEvent.click(addButtons[0]!);

    expect(change).toHaveBeenCalledWith(
      "/chapters/ch-1/events",
      "POST",
      expect.objectContaining({
        participationType: "REQUIRED",
      }),
    );
  });

  it("EventPanel does not render the EXPLORATION_ONLY / REQUIRED participation dropdown", () => {
    wrap(
      <EventPanel
        detail={pathDetailFixture}
        chapter={pathDetailFixture.chapters[0]}
        selectedEventId="en-1"
        disabled={false}
        readOnly={false}
        change={vi.fn()}
        onSelect={vi.fn()}
      />,
    );

    expect(screen.queryByText(/Vai trò trong lộ trình/i)).toBeNull();
    expect(screen.queryByText(/Tham khảo — không chặn tiến độ/i)).toBeNull();
  });

  it("PathPreview renders events as Bắt buộc without Tham khảo label", () => {
    wrap(<PathPreview detail={pathDetailFixture} />);
    expect(screen.getByText("Bắt buộc")).toBeInTheDocument();
    expect(screen.queryByText("Tham khảo")).toBeNull();
  });
});
