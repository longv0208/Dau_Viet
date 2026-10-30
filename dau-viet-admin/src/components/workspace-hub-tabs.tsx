"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { cn } from "@/lib/utils";

export interface HubTabItem {
  href: string;
  label: string;
  badge?: string;
}

export type WorkspaceHubKey =
  | "event-children"
  | "island"
  | "map-and-path";

const HUB_CONFIGS: Record<
  WorkspaceHubKey,
  { groupLabel: string; parentHref?: string; parentLabel?: string; tabs: HubTabItem[] }
> = {
  "event-children": {
    groupLabel: "Thành phần thuộc Sự kiện",
    parentHref: "/events",
    parentLabel: "← Danh sách Sự kiện",
    tabs: [
      { href: "/lessons", label: "Bài học" },
      { href: "/templates", label: "Mẫu bài học" },
      { href: "/evidence", label: "Bằng chứng" },
      { href: "/animations", label: "Hoạt họa lịch sử" },
      { href: "/dossiers", label: "Hồ sơ lịch sử" },
      { href: "/map-locations", label: "Địa điểm di tích" },
      { href: "/versions", label: "Phiên bản xuất bản" },
    ],
  },
  island: {
    groupLabel: "Không gian Đảo Di Sản",
    tabs: [
      { href: "/island-builder", label: "Bố cục Đảo 2.5D" },
      { href: "/island-shop", label: "Cửa hàng Đảo Di Sản" },
      { href: "/items", label: "Danh mục Vật phẩm thưởng" },
    ],
  },
  "map-and-path": {
    groupLabel: "Lộ trình & Bản đồ Lịch sử",
    tabs: [
      { href: "/learning-path", label: "Bản đồ Dấu Ấn (Cây thời kỳ)" },
      { href: "/map-locations", label: "Địa điểm di tích (Ghim bản đồ)" },
    ],
  },
};

/**
 * Thanh chuyển đổi nhanh giữa các màn hình con cùng cụm nghiệp vụ
 * (ví dụ: các nhánh con của Sự kiện, hoặc cụm Đảo Di Sản & Cửa hàng).
 */
export function WorkspaceHubTabs({ hub }: { hub: WorkspaceHubKey }) {
  const pathname = usePathname() ?? "";
  const cfg = HUB_CONFIGS[hub];

  return (
    <div className="mb-4 flex flex-wrap items-center justify-between gap-2 rounded-lg border border-border bg-surface-alt px-3 py-2 shadow-sm">
      <div className="flex flex-wrap items-center gap-1.5" role="navigation" aria-label={cfg.groupLabel}>
        <span className="mr-1 text-xs font-bold uppercase tracking-wider text-ink-muted">
          {cfg.groupLabel}:
        </span>
        {cfg.tabs.map((tab) => {
          const active = pathname === tab.href || pathname.startsWith(`${tab.href}/`);
          return (
            <Link
              key={tab.href}
              href={tab.href}
              aria-current={active ? "page" : undefined}
              className={cn(
                "rounded-md px-2.5 py-1 text-xs font-medium transition-colors",
                active
                  ? "bg-brand text-surface-alt font-semibold shadow-sm"
                  : "text-ink hover:bg-surface",
              )}
            >
              {tab.label}
            </Link>
          );
        })}
      </div>
      {cfg.parentHref && cfg.parentLabel && (
        <Link
          href={cfg.parentHref}
          className="text-xs font-semibold text-brand hover:underline"
        >
          {cfg.parentLabel}
        </Link>
      )}
    </div>
  );
}
