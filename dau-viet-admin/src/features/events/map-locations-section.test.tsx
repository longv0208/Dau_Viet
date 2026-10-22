import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HttpResponse, http } from "msw";
import { describe, expect, it } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";
import type { AdminMapLocation } from "@/lib/dto/map-location";

import { MapLocationsSection } from "./map-locations-section";

const EVENT_ID = "evt-1";
const LOC_ID = "loc-1";
const LESSON_ID = "les-1";

const publishedLoc: AdminMapLocation = {
  id: LOC_ID,
  eventId: EVENT_ID,
  title: "Bến Bạch Đằng",
  description: "desc",
  latitude: 20.9,
  longitude: 106.8,
  unlockLessonId: LESSON_ID,
  unlockLessonTitle: "Trận Bạch Đằng",
  displayOrder: 0,
  status: "PUBLISHED",
  everPublished: true,
  rowVersion: 1,
  createdAt: "2026-01-01T00:00:00Z",
  updatedAt: "2026-01-01T00:00:00Z",
};

const availableLoc: AdminMapLocation = {
  ...publishedLoc,
  id: "loc-2",
  unlockLessonId: null,
  unlockLessonTitle: null,
};

/** Đã publish → demote về DRAFT: unlockLessonId vẫn immutable. */
const demotedDraftLoc: AdminMapLocation = {
  ...publishedLoc,
  id: "loc-3",
  status: "DRAFT",
  everPublished: true,
};

/** Chưa từng publish — DRAFT, prerequisite vẫn editable. */
const freshDraftLoc: AdminMapLocation = {
  ...publishedLoc,
  id: "loc-4",
  status: "DRAFT",
  everPublished: false,
};

/** Đã từng publish → ARCHIVED: immutable. */
const archivedLoc: AdminMapLocation = {
  ...publishedLoc,
  id: "loc-5",
  status: "ARCHIVED",
  everPublished: true,
};

/** ARCHIVED nhưng chưa từng publish (edge case) — vẫn editable. */
const archivedNeverPublishedLoc: AdminMapLocation = {
  ...publishedLoc,
  id: "loc-6",
  status: "ARCHIVED",
  everPublished: false,
};

function renderSection() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <MapLocationsSection eventId={EVENT_ID} />
    </QueryClientProvider>,
  );
}

function mockList(locations: AdminMapLocation[]) {
  server.use(
    http.get(`*/api/proxy/admin/events/${EVENT_ID}/map-locations`, () =>
      HttpResponse.json(locations),
    ),
    http.get(`*/api/proxy/admin/lessons`, () =>
      HttpResponse.json({
        content: [
          { id: LESSON_ID, title: "Trận Bạch Đằng", status: "PUBLISHED", currentVersionId: "v1" },
        ],
        totalPages: 1,
        totalElements: 1,
        number: 0,
        size: 100,
      }),
    ),
  );
}

describe("MapLocationsSection", () => {
  it("PUBLISHED location: metadata PATCH preserves original unlockLessonId", async () => {
    authStore.setAccessToken("t", 900);
    let patched: Record<string, unknown> | null = null;
    mockList([publishedLoc]);
    server.use(
      http.patch(
        `*/api/proxy/admin/events/${EVENT_ID}/map-locations/${LOC_ID}`,
        async ({ request }) => {
          patched = (await request.json()) as Record<string, unknown>;
          return HttpResponse.json({ ...publishedLoc, ...patched });
        },
      ),
    );
    renderSection();
    await waitFor(() => expect(screen.getByText("Bến Bạch Đằng")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: /sửa/i }));
    // Đổi title rồi save — unlockLessonId phải là giá trị gốc, không bị drop.
    const titleInput = screen.getByLabelText(/tên địa điểm/i);
    await userEvent.clear(titleInput);
    await userEvent.type(titleInput, "Tên mới");
    await userEvent.click(screen.getByRole("button", { name: /lưu thay đổi/i }));
    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched).toMatchObject({ title: "Tên mới", unlockLessonId: LESSON_ID });
  });

  it("AVAILABLE location (null lesson): PATCH sends unlockLessonId=null", async () => {
    authStore.setAccessToken("t", 900);
    let patched: Record<string, unknown> | null = null;
    mockList([availableLoc]);
    server.use(
      http.patch(
        `*/api/proxy/admin/events/${EVENT_ID}/map-locations/loc-2`,
        async ({ request }) => {
          patched = (await request.json()) as Record<string, unknown>;
          return HttpResponse.json({ ...availableLoc, ...patched });
        },
      ),
    );
    renderSection();
    await waitFor(() => expect(screen.getByText("Bến Bạch Đằng")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: /sửa/i }));
    const titleInput = screen.getByLabelText(/tên địa điểm/i);
    await userEvent.clear(titleInput);
    await userEvent.type(titleInput, "Tên khác");
    await userEvent.click(screen.getByRole("button", { name: /lưu thay đổi/i }));
    await waitFor(() => expect(patched).not.toBeNull());
    expect(patched).toMatchObject({ title: "Tên khác", unlockLessonId: null });
  });

  it("PUBLISHED location shows read-only lesson text, no editable select", async () => {
    authStore.setAccessToken("t", 900);
    mockList([publishedLoc]);
    renderSection();
    await waitFor(() => expect(screen.getByText("Bến Bạch Đằng")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: /sửa/i }));
    // Read-only text hiển thị lesson title; không có select.
    expect(screen.getByText("Trận Bạch Đằng")).toBeInTheDocument();
    expect(screen.queryByRole("combobox")).not.toBeInTheDocument();
  });

  it("DRAFT + everPublished=true → read-only prerequisite", async () => {
    authStore.setAccessToken("t", 900);
    mockList([demotedDraftLoc]);
    renderSection();
    await waitFor(() => expect(screen.getByText("Bến Bạch Đằng")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: /sửa/i }));
    expect(screen.queryByRole("combobox")).not.toBeInTheDocument();
    expect(screen.getByText("Trận Bạch Đằng")).toBeInTheDocument();
  });

  it("ARCHIVED + everPublished=true → read-only prerequisite", async () => {
    authStore.setAccessToken("t", 900);
    mockList([archivedLoc]);
    renderSection();
    await waitFor(() => expect(screen.getByText("Bến Bạch Đằng")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: /sửa/i }));
    expect(screen.queryByRole("combobox")).not.toBeInTheDocument();
    expect(screen.getByText("Trận Bạch Đằng")).toBeInTheDocument();
  });

  it("DRAFT + everPublished=false → editable select", async () => {
    authStore.setAccessToken("t", 900);
    mockList([freshDraftLoc]);
    renderSection();
    await waitFor(() => expect(screen.getByText("Bến Bạch Đằng")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: /sửa/i }));
    expect(screen.getByRole("combobox")).toBeInTheDocument();
  });

  it("ARCHIVED + everPublished=false → editable select", async () => {
    authStore.setAccessToken("t", 900);
    mockList([archivedNeverPublishedLoc]);
    renderSection();
    await waitFor(() => expect(screen.getByText("Bến Bạch Đằng")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: /sửa/i }));
    expect(screen.getByRole("combobox")).toBeInTheDocument();
  });
});
