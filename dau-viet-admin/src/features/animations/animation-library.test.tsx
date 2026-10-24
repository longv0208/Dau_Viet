import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { http, HttpResponse } from "msw";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { AnimationLibrary } from "./animation-library";

const pushMock = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: pushMock, refresh: vi.fn() }),
}));

function renderLibrary() {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <AnimationLibrary />
    </QueryClientProvider>,
  );
}

const HTML_TPL = {
  id: "d7a11000-0000-4000-8000-000000000001",
  code: "html-webview",
  name: "Hoạt họa HTML",
  rendererCode: "HTML_WEBVIEW",
  rendererVersion: 1,
  schemaVersion: 2,
  enabled: true,
  createdAt: "2026-01-01T00:00:00Z",
  updatedAt: "2026-01-01T00:00:00Z",
};

describe("AnimationLibrary — FIX-01 HTML template identification", () => {
  it("chọn template chuẩn theo code 'html-webview', không lấy content[0]", async () => {
    authStore.setAccessToken("t", 900);
    // Fixture: 'html-custom' (HTML_WEBVIEW) xếp TRƯỚC 'html-webview' chuẩn.
    // Lấy content[0] → filter sai templateId → trả rỗng.
    renderLibrary();
    await waitFor(() =>
      expect(screen.getByText("Hoạt họa HTML mẫu")).toBeInTheDocument(),
    );
  });

  it("không có template chuẩn → hiển thị ErrorState, không skeleton mãi", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.get("*/api/proxy/admin/animation-templates", () =>
        HttpResponse.json({
          content: [{ ...HTML_TPL, code: "html-custom" }],
          page: 0,
          size: 100,
          totalElements: 1,
          totalPages: 1,
        }),
      ),
    );
    renderLibrary();
    // ErrorState render "Có lỗi xảy ra" + nút Thử lại.
    await waitFor(() =>
      expect(screen.getByText(/có lỗi xảy ra/i)).toBeInTheDocument(),
    );
    expect(
      screen.getAllByRole("button").filter((b) => /thử lại/i.test(b.textContent ?? "")),
    ).not.toHaveLength(0);
    // Không hiển thị scene (scene query không chạy).
    expect(screen.queryByText("Hoạt họa HTML mẫu")).toBeNull();
  });

  it("template API trả rỗng → cũng hiển thị ErrorState", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.get("*/api/proxy/admin/animation-templates", () =>
        HttpResponse.json({
          content: [],
          page: 0,
          size: 100,
          totalElements: 0,
          totalPages: 0,
        }),
      ),
    );
    renderLibrary();
    await waitFor(() =>
      expect(screen.getByText(/có lỗi xảy ra/i)).toBeInTheDocument(),
    );
  });

  it("template API lỗi → ErrorState + retry chạy lại template query", async () => {
    authStore.setAccessToken("t", 900);
    let calls = 0;
    server.use(
      http.get("*/api/proxy/admin/animation-templates", () => {
        calls++;
        if (calls === 1) {
          return HttpResponse.json(
            { code: "INTERNAL_ERROR", message: "server error" },
            { status: 500 },
          );
        }
        return HttpResponse.json({
          content: [HTML_TPL],
          page: 0,
          size: 100,
          totalElements: 1,
          totalPages: 1,
        });
      }),
    );
    renderLibrary();
    await waitFor(() =>
      expect(screen.getAllByText(/có lỗi xảy ra/i).length).toBeGreaterThan(0),
    );
    const retryBtns = screen
      .getAllByRole("button")
      .filter((b) => /thử lại/i.test(b.textContent ?? ""));
    await userEvent.click(retryBtns[0]!);
    await waitFor(() =>
      expect(screen.getByText("Hoạt họa HTML mẫu")).toBeInTheDocument(),
    );
    expect(calls).toBe(2);
  });
});

describe("AnimationLibrary — FIX-02 retry/error states", () => {
  it("lỗi tải scene → ErrorState, retry chạy lại scene query", async () => {
    authStore.setAccessToken("t", 900);
    let calls = 0;
    server.use(
      http.get("*/api/proxy/admin/animation-scenes", () => {
        calls++;
        if (calls === 1) {
          return HttpResponse.json(
            { code: "INTERNAL_ERROR", message: "server error" },
            { status: 500 },
          );
        }
        return HttpResponse.json({
          content: [
            {
              id: "dddddddd-dddd-dddd-dddd-dddddddddddd",
              templateId: "d7a11000-0000-4000-8000-000000000001",
              title: "Hoạt họa HTML mẫu",
              status: "PUBLISHED",
              currentVersionId: "v1",
              currentVersionNo: 1,
              rowVersion: 2,
              updatedAt: "2026-01-05T00:00:00Z",
            },
          ],
          page: 0,
          size: 20,
          totalElements: 1,
          totalPages: 1,
        });
      }),
    );
    renderLibrary();
    await waitFor(() =>
      expect(screen.getAllByText(/có lỗi xảy ra/i).length).toBeGreaterThan(0),
    );
    const retryBtns = screen
      .getAllByRole("button")
      .filter((b) => /thử lại/i.test(b.textContent ?? ""));
    await userEvent.click(retryBtns[0]!);
    await waitFor(() =>
      expect(screen.getByText("Hoạt họa HTML mẫu")).toBeInTheDocument(),
    );
  });

  it("không bao giờ gọi scene API khi chưa có htmlTemplateId", async () => {
    authStore.setAccessToken("t", 900);
    const sceneCalls: string[] = [];
    server.use(
      http.get("*/api/proxy/admin/animation-scenes", ({ request }) => {
        sceneCalls.push(new URL(request.url).toString());
        return HttpResponse.json({
          content: [],
          page: 0,
          size: 20,
          totalElements: 0,
          totalPages: 0,
        });
      }),
    );
    renderLibrary();
    await waitFor(() => expect(sceneCalls.length).toBeGreaterThan(0));
    for (const url of sceneCalls) {
      expect(url).toContain("templateId=d7a11000-0000-4000-8000-000000000001");
    }
  });
});

describe("AnimationLibrary — FIX-06 HTML-only UI", () => {
  it("dropzone luôn hiện khi mở trang", () => {
    authStore.setAccessToken("t", 900);
    renderLibrary();
    expect(screen.getByText(/kéo thả tệp \.html/i)).toBeInTheDocument();
    // Dropzone chứa nút 'Chọn tệp…' (thật button) + vùng dropzone (role=button).
    const buttons = screen
      .getAllByRole("button")
      .filter((b) => /chọn tệp/i.test(b.textContent ?? ""));
    expect(buttons.length).toBeGreaterThan(0);
  });

  it("không có nút tạo scene kiểu cũ", () => {
    authStore.setAccessToken("t", 900);
    renderLibrary();
    // Không có "+ Tạo hoạt họa mới" hay TemplatePicker.
    expect(
      screen.queryByRole("button", { name: /tạo hoạt họa mới|tạo cảnh mới/i }),
    ).toBeNull();
    expect(
      screen.queryByText(/tạo scene tương tác|không cần viết code/i),
    ).toBeNull();
  });

  it("danh sách chỉ có HTML scenes (legacy bị lọc server-side)", async () => {
    authStore.setAccessToken("t", 900);
    renderLibrary();
    await waitFor(() =>
      expect(screen.getByText("Hoạt họa HTML mẫu")).toBeInTheDocument(),
    );
    expect(screen.queryByText("Trận thủy chiến Bạch Đằng 938")).toBeNull();
    expect(screen.queryByText("Hành trình về Thăng Long 1010")).toBeNull();
    expect(screen.queryByText("Cảnh nháp chưa xuất bản")).toBeNull();
  });

  it("import success → điều hướng tới editor", async () => {
    authStore.setAccessToken("t", 900);
    renderLibrary();
    // File input nằm trong dropzone — query trực tiếp.
    const input = document.querySelector<HTMLInputElement>(
      "input[type=file]",
    );
    expect(input).not.toBeNull();
    const file = new File(["<html></html>"], "test.html", {
      type: "text/html",
    });
    await userEvent.upload(input!, file);
    await waitFor(() =>
      expect(pushMock).toHaveBeenCalledWith(
        "/animations/dddddddd-dddd-dddd-dddd-dddddddddddd/edit",
      ),
    );
  });
});
