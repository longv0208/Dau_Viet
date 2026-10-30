import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import { HttpResponse, http } from "msw";
import { describe, expect, it } from "vitest";

import { server } from "@/test/msw/server";
import { authStore } from "@/features/auth/auth-store";

import { ItemsTable } from "./items-table";

function renderTable() {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <ItemsTable />
    </QueryClientProvider>,
  );
}

describe("ItemsTable — Contextual tooltips & direct configuration links (Issue #44 AC-4)", () => {
  it("renders Vietnamese column headers with sans-serif typography, tooltips, and direct unlock configuration links", async () => {
    authStore.setAccessToken("test-access-token", 900);
    server.use(
      http.get("*/api/proxy/admin/items", () =>
        HttpResponse.json({
          content: [
            {
              id: "item-1",
              code: "decor.dinh_lang",
              name: "Đình làng cổ truyền",
              description: "Mô hình trang trí đảo",
              category: "DECOR",
              itemType: "DECOR",
              rarity: "RARE",
              active: true,
              placeable: true,
              renderKey: "decor.dinh_lang",
              rowVersion: 1,
              rule: null,
            },
            {
              id: "item-2",
              code: "badge.bach_dang",
              name: "Huy hiệu Bạch Đằng",
              description: "Huy hiệu kỷ niệm",
              category: "HUY_HIEU",
              itemType: "COMMEMORATIVE_BADGE",
              rarity: "EPIC",
              active: true,
              placeable: false,
              renderKey: null,
              rowVersion: 1,
              rule: {
                id: "rule-1",
                ruleType: "LESSON_COMPLETED",
                threshold: null,
                active: true,
              },
            },
          ],
          page: 0,
          size: 20,
          totalElements: 2,
          totalPages: 1,
        }),
      ),
    );

    renderTable();

    await waitFor(() => {
      expect(screen.getByText("Đình làng cổ truyền")).toBeInTheDocument();
    });

    // Unconfigured rule shows direct link to /items/item-1#unlock-rule
    const configureRuleLink = screen.getByRole("link", {
      name: "+ Gắn vào bài học / sự kiện →",
    });
    expect(configureRuleLink).toHaveAttribute("href", "/items/item-1#unlock-rule");

    // Configured rule shows direct edit link
    const editRuleLink = screen.getByRole("link", {
      name: "Sửa điều kiện mở khóa →",
    });
    expect(editRuleLink).toHaveAttribute("href", "/items/item-2#unlock-rule");

    // Placeable item shows direct link to Island Shop
    const shopLink = screen.getByRole("link", {
      name: "Cấu hình bán tại Shop →",
    });
    expect(shopLink).toHaveAttribute("href", "/island-shop");
  });
});
