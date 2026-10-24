import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { HtmlSceneEditor } from "./html-scene-editor";
import { animationApi } from "./animation-api";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), refresh: vi.fn() }),
}));

// URL.createObjectURL/revokeObjectURL không có trong jsdom — gán trực tiếp
// lên constructor để giữ nguyên `new URL()`.
Object.assign(URL, {
  createObjectURL: vi.fn(() => "blob:mock-url"),
  revokeObjectURL: vi.fn(),
});

const SCENE = {
  id: "dddddddd-dddd-dddd-dddd-dddddddddddd",
  templateId: "d7a11000-0000-4000-8000-000000000001",
  eventId: null,
  title: "Hoạt họa HTML mẫu",
  status: "PUBLISHED",
  currentVersionId: "v1",
  currentVersionNo: 1,
  rowVersion: 2,
  updatedAt: "2026-01-05T00:00:00Z",
  createdBy: "u",
  updatedBy: "u",
  createdAt: "2026-01-01T00:00:00Z",
  draftJson: JSON.stringify({
    schemaVersion: 2,
    rendererCode: "HTML_WEBVIEW",
    rendererVersion: 1,
    title: "Hoạt họa HTML mẫu",
    html: { filename: "hoat-hoa.html", sizeBytes: 8192, sha256: "abc123" },
  }),
};

function renderEditor() {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <HtmlSceneEditor sceneId="dddddddd-dddd-dddd-dddd-dddddddddddd" />
    </QueryClientProvider>,
  );
}

describe("HtmlSceneEditor — FIX-05 file information", () => {
  it("getScene trả scene đúng", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.get("*/api/proxy/admin/animation-scenes/:id", () =>
        HttpResponse.json(SCENE),
      ),
    );
    const scene = await animationApi.getScene(SCENE.id);
    expect(scene.title).toBe("Hoạt họa HTML mẫu");
  });

  it("hiển thị filename/sizeBytes/version/status từ server draft", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.get("*/api/proxy/admin/animation-scenes/:id", () =>
        HttpResponse.json(SCENE),
      ),
      http.get("*/api/proxy/admin/animation-scenes/:id/html-draft", () =>
        new HttpResponse("<html></html>", {
          headers: { "Content-Type": "text/html" },
        }),
      ),
    );
    renderEditor();
    await waitFor(() =>
      expect(screen.getByText("hoat-hoa.html")).toBeInTheDocument(),
    );
    expect(screen.getByText(/8\.0 KB|8 KB/)).toBeInTheDocument();
    expect(screen.getByText("v1")).toBeInTheDocument();
  });
});

describe("HtmlSceneEditor — FIX-03 archive read-only", () => {
  it("archive thành công → status ARCHIVED, ẩn edit controls", async () => {
    authStore.setAccessToken("t", 900);
    let archived = false;
    server.use(
      http.get("*/api/proxy/admin/animation-scenes/:id", () =>
        HttpResponse.json(
          archived
            ? { ...SCENE, status: "ARCHIVED", rowVersion: 3 }
            : SCENE,
        ),
      ),
      http.get("*/api/proxy/admin/animation-scenes/:id/html-draft", () =>
        new HttpResponse("<html></html>", {
          headers: { "Content-Type": "text/html" },
        }),
      ),
      http.post("*/api/proxy/admin/animation-scenes/:id/archive", () => {
        archived = true;
        return HttpResponse.json({ ...SCENE, status: "ARCHIVED", rowVersion: 3 });
      }),
    );
    renderEditor();
    // Mở section Xuất bản & phiên bản (defaultOpen=false).
    await waitFor(() =>
      expect(screen.getByText("Xuất bản & phiên bản")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByText("Xuất bản & phiên bản"));
    await waitFor(() =>
      expect(screen.getByText("Lưu trữ cảnh")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByText("Lưu trữ cảnh"));
    await waitFor(() =>
      expect(screen.getByText(/cảnh đã lưu trữ/i)).toBeInTheDocument(),
    );
    // Sau archive: nút Lưu tên và Xuất bản bị ẩn/disabled.
    expect(screen.queryByText("Xuất bản phiên bản mới")).toBeNull();
  });

  it("archive API lỗi → không hiển thị trạng thái archived", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.get("*/api/proxy/admin/animation-scenes/:id", () =>
        HttpResponse.json(SCENE),
      ),
      http.get("*/api/proxy/admin/animation-scenes/:id/html-draft", () =>
        new HttpResponse("<html></html>", {
          headers: { "Content-Type": "text/html" },
        }),
      ),
      http.post("*/api/proxy/admin/animation-scenes/:id/archive", () =>
        HttpResponse.json(
          { code: "INVALID_STATUS_TRANSITION", message: "lỗi" },
          { status: 409 },
        ),
      ),
    );
    renderEditor();
    await waitFor(() =>
      expect(screen.getByText("Xuất bản & phiên bản")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByText("Xuất bản & phiên bản"));
    await waitFor(() =>
      expect(screen.getByText("Lưu trữ cảnh")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByText("Lưu trữ cảnh"));
    // Không chuyển sang archived state.
    await waitFor(() =>
      expect(screen.queryByText(/cảnh đã lưu trữ/i)).toBeNull(),
    );
    // Nút Xuất bản vẫn còn.
    expect(screen.getByText("Xuất bản phiên bản mới")).toBeInTheDocument();
  });
});

describe("HtmlSceneEditor — FIX-04 preview stale blob", () => {
  it("preview fetch lỗi → không giữ iframe cũ", async () => {
    authStore.setAccessToken("t", 900);
    let previewCalls = 0;
    server.use(
      http.get("*/api/proxy/admin/animation-scenes/:id", () =>
        HttpResponse.json(SCENE),
      ),
      http.get("*/api/proxy/admin/animation-scenes/:id/html-draft", () => {
        previewCalls++;
        if (previewCalls === 1) {
          return new HttpResponse("<html></html>", {
            headers: { "Content-Type": "text/html" },
          });
        }
        return HttpResponse.json(
          { code: "INTERNAL_ERROR", message: "server error" },
          { status: 500 },
        );
      }),
    );
    renderEditor();
    // Lần 1: preview OK → iframe hiện.
    await waitFor(() =>
      expect(screen.getByTitle(/xem trước hoạt họa html/i)).toBeInTheDocument(),
    );
    // Bấm Tải lại → lần 2 lỗi → iframe biến mất.
    await userEvent.click(
      screen.getAllByRole("button").filter((b) => /tải lại/i.test(b.textContent ?? ""))[0]!,
    );
    await waitFor(() =>
      expect(
        screen.getByText(/không tải được bản nháp/i),
      ).toBeInTheDocument(),
    );
    expect(screen.queryByTitle(/xem trước hoạt họa html/i)).toBeNull();
  });
});
