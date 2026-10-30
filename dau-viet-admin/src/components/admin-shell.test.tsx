import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { NavLinks } from "./admin-shell";
import { PageGuideBanner } from "./page-guide-banner";

let currentPathname = "/dashboard";

vi.mock("next/navigation", () => ({
  usePathname: () => currentPathname,
}));

describe("NavLinks — Hierarchical Tree Sidebar (Issue #44 AC-2)", () => {
  it("renders 3 functional groups and places event-related screens as child branches under Sự kiện", () => {
    currentPathname = "/dashboard";
    render(<NavLinks collapsed={false} />);

    // 3 group headers
    expect(screen.getByText("Bắt đầu & Biên tập chính")).toBeInTheDocument();
    expect(screen.getByText("Kho dùng chung")).toBeInTheDocument();
    expect(screen.getByText("Gamification & Đảo Di Sản")).toBeInTheDocument();

    // Child branch list under "Sự kiện"
    const eventChildrenList = screen.getByRole("list", { name: "Nhánh con Sự kiện" });
    for (const childLabel of [
      "Bài học",
      "Mẫu bài học",
      "Bằng chứng",
      "Hoạt họa lịch sử",
      "Hồ sơ lịch sử",
      "Địa điểm di tích",
      "Phiên bản",
    ]) {
      expect(within(eventChildrenList).getByRole("link", { name: childLabel })).toBeInTheDocument();
    }

    // Child branch list under "Đảo Di Sản"
    const islandChildrenList = screen.getByRole("list", { name: "Nhánh con Đảo Di Sản" });
    expect(
      within(islandChildrenList).getByRole("link", { name: "Cửa hàng Đảo Di Sản" }),
    ).toBeInTheDocument();
  });

  it("allows collapsing and expanding the Sự kiện child branch when on another page", async () => {
    currentPathname = "/dashboard";
    const user = userEvent.setup();
    render(<NavLinks collapsed={false} />);

    const toggleBtn = screen.getByRole("button", { name: "Thu gọn nhánh Sự kiện" });
    await user.click(toggleBtn);
    expect(screen.queryByRole("list", { name: "Nhánh con Sự kiện" })).not.toBeInTheDocument();

    const expandBtn = screen.getByRole("button", { name: "Mở rộng nhánh Sự kiện" });
    await user.click(expandBtn);
    expect(screen.getByRole("list", { name: "Nhánh con Sự kiện" })).toBeInTheDocument();
  });

  it("marks the child link as aria-current=page and still allows collapsing the parent branch when on an event child route", async () => {
    currentPathname = "/lessons";
    const user = userEvent.setup();
    render(<NavLinks collapsed={false} />);

    const lessonLink = screen.getByRole("link", { name: "Bài học" });
    expect(lessonLink).toHaveAttribute("aria-current", "page");

    const toggleBtn = screen.getByRole("button", { name: "Thu gọn nhánh Sự kiện" });
    await user.click(toggleBtn);
    expect(screen.queryByRole("list", { name: "Nhánh con Sự kiện" })).not.toBeInTheDocument();
  });
});

describe("PageGuideBanner — Contextual Guidance (Issue #44 AC-4)", () => {
  it("renders 3 guidance columns and toggles visibility", async () => {
    const user = userEvent.setup();
    render(
      <PageGuideBanner
        storageKey="test-guide"
        title="Vật phẩm thưởng"
        purpose="Quản lý danh mục vật phẩm học tập."
        appSurface="Hiển thị tại Kho Sưu tập."
        nextStep="Cấu hình điều kiện mở khóa."
        links={[{ href: "/island-shop", label: "Mở Cửa hàng" }]}
      />,
    );

    expect(screen.getByText("Quản lý danh mục vật phẩm học tập.")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /Mở Cửa hàng/ })).toHaveAttribute("href", "/island-shop");

    await user.click(screen.getByRole("button", { name: /Thu gọn hướng dẫn/ }));
    expect(screen.queryByText("Quản lý danh mục vật phẩm học tập.")).not.toBeInTheDocument();
  });
});
