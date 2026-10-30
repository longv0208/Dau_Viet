import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HttpResponse, http } from "msw";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { EventForm } from "./event-form";

const pushMock = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock, replace: vi.fn() }),
}));

function renderForm(initial?: Parameters<typeof EventForm>[0]["initial"]) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <EventForm initial={initial} />
    </QueryClientProvider>,
  );
}

describe("EventForm", () => {
  it("shows Vietnamese validation errors on empty submit", async () => {
    authStore.setAccessToken("t", 900);
    renderForm();
    await userEvent.click(screen.getByRole("button", { name: /tạo sự kiện/i }));
    await waitFor(() => {
      expect(screen.getByText("Vui lòng nhập tiêu đề")).toBeInTheDocument();
      expect(screen.getByText("Vui lòng nhập tóm tắt")).toBeInTheDocument();
    });
  });

  it("auto-suggests a kebab-case slug from the title", async () => {
    authStore.setAccessToken("t", 900);
    renderForm();
    await userEvent.type(screen.getByLabelText(/tiêu đề/i), "Trận Bạch Đằng 938");
    await waitFor(() =>
      expect(screen.getByLabelText(/đường dẫn rút gọn/i)).toHaveValue("tran-bach-dang-938"),
    );
  });

  it("creates an event and navigates to its editor", async () => {
    authStore.setAccessToken("t", 900);
    let posted: Record<string, unknown> | null = null;
    server.use(
      http.post("*/api/proxy/admin/events", async ({ request }) => {
        posted = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ id: "evt-new", ...posted }, { status: 201 });
      }),
    );
    renderForm();
    await userEvent.type(screen.getByLabelText(/tiêu đề/i), "Trận Bạch Đằng 938");
    await userEvent.type(screen.getByLabelText(/năm bắt đầu/i), "938");
    await userEvent.type(screen.getByLabelText(/tóm tắt/i), "Chiến thắng lịch sử");
    await userEvent.click(screen.getByRole("button", { name: /tạo sự kiện/i }));
    await waitFor(() => expect(pushMock).toHaveBeenCalledWith("/events/evt-new"));
    expect(posted).toMatchObject({
      title: "Trận Bạch Đằng 938",
      slug: "tran-bach-dang-938",
      summary: "Chiến thắng lịch sử",
    });
    // Contract: startYear goes over the wire as a number, not a string.
    expect(posted!.startYear).toBe(938);
  });

  it("maps a backend VALIDATION_ERROR onto the slug field", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.post("*/api/proxy/admin/events", () =>
        HttpResponse.json(
          {
            code: "VALIDATION_ERROR",
            message: "Validation failed",
            details: { slug: "slug must be lowercase kebab-case" },
            // ASCII-only backend detail → replaced by generic Vietnamese message.
          },
          { status: 400 },
        ),
      ),
    );
    renderForm();
    await userEvent.type(screen.getByLabelText(/tiêu đề/i), "X");
    await userEvent.type(screen.getByLabelText(/tóm tắt/i), "Y");
    await userEvent.click(screen.getByRole("button", { name: /tạo sự kiện/i }));
    await waitFor(() =>
      expect(screen.getByText("Giá trị chưa hợp lệ")).toBeInTheDocument(),
    );
  });

  it("edits an existing event with expectedRowVersion", async () => {
    authStore.setAccessToken("t", 900);
    let patched: Record<string, unknown> | null = null;
    server.use(
      http.patch("*/api/proxy/admin/events/evt-1", async ({ request }) => {
        patched = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({
          id: "evt-1",
          ...patched,
          status: "DRAFT",
          rowVersion: 2,
          createdAt: "2026-01-01T00:00:00Z",
          updatedAt: "2026-01-02T00:00:00Z",
        });
      }),
    );
    renderForm({
      id: "evt-1",
      slug: "old",
      title: "Old title",
      era: null,
      period: null,
      startYear: null,
      summary: "old sum",
      description: null,
      location: null,
      coverAssetKey: null,
      tags: [],
      status: "DRAFT",
      rowVersion: 1,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
    });
    const titleInput = screen.getByLabelText(/tiêu đề/i);
    await userEvent.clear(titleInput);
    await userEvent.type(titleInput, "New title");
    await userEvent.click(screen.getByRole("button", { name: /lưu thay đổi/i }));
    await waitFor(() => expect(screen.getByText("Đã lưu thay đổi.")).toBeInTheDocument());
    expect(patched).toMatchObject({ title: "New title", expectedRowVersion: 1 });
  });

  it("picks a cover image from the media library and submits coverAssetKey", async () => {
    authStore.setAccessToken("t", 900);
    const assetId = "d7a70000-0000-4000-8000-000000000003";
    let posted: Record<string, unknown> | null = null;
    server.use(
      http.get("*/api/proxy/admin/assets", () =>
        HttpResponse.json({
          content: [
            {
              id: assetId,
              originalFilename: "bai-coc-bach-dang.jpg",
              mimeType: "image/jpeg",
              sizeBytes: 102400,
              state: "ACTIVE",
              altText: "Bãi cọc Bạch Đằng",
              createdAt: "2026-01-01T00:00:00Z",
              contentUrl: `/api/v1/admin/assets/${assetId}/content`,
            },
          ],
          page: 0,
          size: 24,
          totalElements: 1,
          totalPages: 1,
        }),
      ),
      http.get(`*/api/proxy/admin/assets/${assetId}/content`, () =>
        new HttpResponse(new Uint8Array([137, 80, 78, 71]), {
          status: 200,
          headers: { "content-type": "image/jpeg" },
        }),
      ),
      http.post("*/api/proxy/admin/events", async ({ request }) => {
        posted = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ id: "evt-cover", ...posted }, { status: 201 });
      }),
    );

    renderForm();
    await userEvent.click(screen.getAllByRole("button", { name: /chọn từ thư viện/i })[0]!);
    const tile = await screen.findByRole("button", { name: /bai-coc-bach-dang\.jpg/i });
    await userEvent.click(tile);

    await waitFor(() =>
      expect(screen.getByText("bai-coc-bach-dang.jpg")).toBeInTheDocument(),
    );

    await userEvent.type(screen.getByLabelText(/tiêu đề/i), "Trận Bạch Đằng 938");
    await userEvent.type(screen.getByLabelText(/tóm tắt/i), "Chiến thắng lịch sử");
    await userEvent.click(screen.getByRole("button", { name: /tạo sự kiện/i }));

    await waitFor(() => expect(posted).not.toBeNull());
    expect(posted).toMatchObject({
      title: "Trận Bạch Đằng 938",
      coverAssetKey: assetId,
    });
  });

  it("uploads a cover image directly and allows clearing it", async () => {
    authStore.setAccessToken("t", 900);
    const uploadedId = "d7a70000-0000-4000-8000-000000000099";
    server.use(
      http.post("*/api/upload/assets", () =>
        HttpResponse.json(
          {
            id: uploadedId,
            originalFilename: "hero-upload.png",
            mimeType: "image/png",
            sizeBytes: 40960,
            state: "ACTIVE",
            altText: null,
            createdAt: "2026-01-01T00:00:00Z",
            contentUrl: `/api/v1/admin/assets/${uploadedId}/content`,
          },
          { status: 201 },
        ),
      ),
      http.get(`*/api/proxy/admin/assets/${uploadedId}/content`, () =>
        new HttpResponse(new Uint8Array([137, 80, 78, 71]), {
          status: 200,
          headers: { "content-type": "image/png" },
        }),
      ),
    );

    renderForm();
    const fileInput = screen.getByLabelText(/tải tệp ảnh bìa lên/i);
    const file = new File([new Uint8Array([137, 80, 78, 71])], "hero-upload.png", {
      type: "image/png",
    });
    await userEvent.upload(fileInput, file);

    await waitFor(() =>
      expect(screen.getByText("hero-upload.png")).toBeInTheDocument(),
    );

    await userEvent.click(screen.getByRole("button", { name: /gỡ ảnh/i }));
    await waitFor(() =>
      expect(screen.getByText("Chưa có ảnh bìa sự kiện")).toBeInTheDocument(),
    );
  });
});
