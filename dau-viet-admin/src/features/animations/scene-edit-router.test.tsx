import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import { describe, expect, it, vi } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { SceneEditRouter } from "./scene-edit-router";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), refresh: vi.fn() }),
}));

vi.mock("./html-scene-editor", () => ({
  HtmlSceneEditor: ({ sceneId }: { sceneId: string }) => (
    <div data-testid="html-scene-editor">{sceneId}</div>
  ),
}));

function renderRouter(sceneId: string) {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <SceneEditRouter sceneId={sceneId} />
    </QueryClientProvider>,
  );
}

const baseScene = {
  id: "x",
  templateId: "t",
  eventId: null,
  title: "Cảnh",
  status: "PUBLISHED",
  currentVersionId: "v1",
  currentVersionNo: 1,
  rowVersion: 1,
  updatedAt: "2026-01-01T00:00:00Z",
  createdBy: "u",
  updatedBy: "u",
  createdAt: "2026-01-01T00:00:00Z",
};

describe("SceneEditRouter — FIX-06 edit page routing", () => {
  it("HTML_WEBVIEW → HtmlSceneEditor", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.get("*/api/proxy/admin/animation-scenes/:id", () =>
        HttpResponse.json({
          ...baseScene,
          id: "dddddddd-dddd-dddd-dddd-dddddddddddd",
          draftJson: JSON.stringify({ rendererCode: "HTML_WEBVIEW" }),
        }),
      ),
    );
    renderRouter("dddddddd-dddd-dddd-dddd-dddddddddddd");
    await waitFor(() =>
      expect(screen.getByTestId("html-scene-editor")).toBeInTheDocument(),
    );
  });

  it("RIVER_TIDE → read-only notice, không render editor cũ", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.get("*/api/proxy/admin/animation-scenes/:id", () =>
        HttpResponse.json({
          ...baseScene,
          id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
          title: "Trận Bạch Đằng",
          draftJson: JSON.stringify({ rendererCode: "RIVER_TIDE" }),
        }),
      ),
    );
    renderRouter("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    await waitFor(() =>
      expect(
        screen.getByText(/trình soạn cảnh kiểu cũ đã ngừng hỗ trợ/i),
      ).toBeInTheDocument(),
    );
    expect(screen.queryByTestId("html-scene-editor")).toBeNull();
    expect(screen.getByText("Trận Bạch Đằng")).toBeInTheDocument();
  });

  it("JOURNEY_MAP → read-only notice", async () => {
    authStore.setAccessToken("t", 900);
    server.use(
      http.get("*/api/proxy/admin/animation-scenes/:id", () =>
        HttpResponse.json({
          ...baseScene,
          id: "cccccccc-cccc-cccc-cccc-cccccccccccc",
          draftJson: JSON.stringify({ rendererCode: "JOURNEY_MAP" }),
        }),
      ),
    );
    renderRouter("cccccccc-cccc-cccc-cccc-cccccccccccc");
    await waitFor(() =>
      expect(
        screen.getByText(/trình soạn cảnh kiểu cũ đã ngừng hỗ trợ/i),
      ).toBeInTheDocument(),
    );
    expect(screen.queryByTestId("html-scene-editor")).toBeNull();
  });

  it("scene không tồn tại → error state an toàn", async () => {
    authStore.setAccessToken("t", 900);
    renderRouter("00000000-0000-0000-0000-000000000000");
    await waitFor(() =>
      expect(screen.getByRole("alert")).toBeInTheDocument(),
    );
    expect(screen.queryByTestId("html-scene-editor")).toBeNull();
  });
});
