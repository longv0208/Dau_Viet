"use client";

import {
  BookMarked,
  BookOpen,
  Calendar,
  ChevronDown,
  ChevronRight,
  Compass,
  FileText,
  Film,
  Gift,
  HeartPulse,
  History,
  Image as ImageIcon,
  LayoutDashboard,
  LayoutTemplate,
  LogOut,
  MapPin,
  Menu,
  PanelLeftClose,
  PanelLeftOpen,
  Route,
  Store,
} from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

import { cn } from "@/lib/utils";
import type { UserProfileDto } from "@/lib/dto/user";
import { useLogout } from "@/features/auth/use-auth";
import { SessionBootstrap } from "@/features/auth/session-bootstrap";

import { Breadcrumbs } from "./breadcrumbs";

export interface NavChildItem {
  href: string;
  label: string;
  desc?: string;
  icon: React.ComponentType<{ className?: string }>;
}

export interface NavItem {
  href: string;
  label: string;
  desc?: string;
  icon: React.ComponentType<{ className?: string }>;
  children?: NavChildItem[];
}

export interface NavGroup {
  id: string;
  title: string;
  items: NavItem[];
}

// Cấu trúc điều hướng phân cấp: giữ "Sự kiện" làm nhánh gốc trung tâm,
// toàn bộ thành phần thuộc Sự kiện (Bài học, Mẫu bài học, Bằng chứng, Hoạt họa,
// Hồ sơ, Địa điểm di tích, Phiên bản) nằm gọn trong nhánh con của Sự kiện.
export const NAV_GROUPS: NavGroup[] = [
  {
    id: "core",
    title: "Bắt đầu & Biên tập chính",
    items: [
      {
        href: "/dashboard",
        label: "Tổng quan",
        desc: "Hướng dẫn 4 bước & trạng thái",
        icon: LayoutDashboard,
      },
      {
        href: "/events",
        label: "Sự kiện",
        desc: "Không gian biên tập sự kiện",
        icon: Calendar,
        children: [
          { href: "/lessons", label: "Bài học", desc: "Kịch bản 4 giai đoạn điều tra", icon: BookOpen },
          { href: "/templates", label: "Mẫu bài học", desc: "Khung hoạt động chuẩn", icon: LayoutTemplate },
          { href: "/evidence", label: "Bằng chứng", desc: "Tư liệu nguồn chứng thực", icon: FileText },
          { href: "/animations", label: "Hoạt họa lịch sử", desc: "Cảnh tương tác HTML", icon: Film },
          { href: "/dossiers", label: "Hồ sơ lịch sử", desc: "Nhân vật, hiện vật, địa danh", icon: BookMarked },
          { href: "/map-locations", label: "Địa điểm di tích", desc: "Ghim bản đồ gắn sự kiện", icon: MapPin },
          { href: "/versions", label: "Phiên bản", desc: "Lịch sử xuất bản bài học", icon: History },
        ],
      },
      {
        href: "/learning-path",
        label: "Bản đồ Dấu Ấn",
        desc: "Lộ trình học theo Thời kỳ",
        icon: Route,
      },
    ],
  },
  {
    id: "library",
    title: "Kho dùng chung",
    items: [
      {
        href: "/assets",
        label: "Thư viện media",
        desc: "Hình ảnh & tệp toàn hệ thống",
        icon: ImageIcon,
      },
    ],
  },
  {
    id: "gamification",
    title: "Gamification & Đảo Di Sản",
    items: [
      {
        href: "/island-builder",
        label: "Đảo Di Sản",
        desc: "Bố cục đảo 2.5D & cửa hàng",
        icon: Compass,
        children: [
          {
            href: "/island-shop",
            label: "Cửa hàng Đảo Di Sản",
            desc: "Bày bán vật phẩm trang trí",
            icon: Store,
          },
        ],
      },
      {
        href: "/items",
        label: "Vật phẩm thưởng",
        desc: "Mô hình, huy hiệu & mở khóa",
        icon: Gift,
      },
      {
        href: "/thai-y-vien",
        label: "Viện Thái Y & Thể lực",
        desc: "Thể lực & phương thuốc hồi phục",
        icon: HeartPulse,
      },
    ],
  },
];

function isPathMatching(pathname: string | null, href: string): boolean {
  if (!pathname) return false;
  return pathname === href || pathname.startsWith(`${href}/`);
}

export function NavLinks({
  collapsed,
  onNavigate,
}: {
  collapsed: boolean;
  onNavigate?: () => void;
}) {
  const pathname = usePathname();
  // Mặc định mở sẵn nhánh "Sự kiện" và "Đảo Di Sản" để người mới nhìn rõ các nhánh con
  const [openBranches, setOpenBranches] = useState<Record<string, boolean>>({
    "/events": true,
    "/island-builder": true,
  });
  useEffect(() => {
    if (!pathname) return;
    for (const group of NAV_GROUPS) {
      for (const item of group.items) {
        if (item.children?.some((c) => isPathMatching(pathname, c.href))) {
          setOpenBranches((prev) =>
            prev[item.href] === true ? prev : { ...prev, [item.href]: true },
          );
        }
      }
    }
  }, [pathname]);

  const toggleBranch = (href: string) => {
    setOpenBranches((prev) => ({
      ...prev,
      [href]: !(prev[href] ?? true),
    }));
  };
  return (
    <nav aria-label="Điều hướng chính" className="flex flex-col gap-3 p-2">
      {NAV_GROUPS.map((group, groupIdx) => (
        <div key={group.id} className="flex flex-col gap-1">
          {!collapsed ? (
            <p className="px-3 pb-1 pt-1 font-sans text-[11px] font-bold uppercase tracking-wider text-ink-muted">
              {group.title}
            </p>
          ) : (
            groupIdx > 0 && <div className="mx-2 my-1 border-t border-border" aria-hidden />
          )}

          {group.items.map((item) => {
            const Icon = item.icon;
            const selfActive = isPathMatching(pathname, item.href);
            const hasChildren = Boolean(item.children && item.children.length > 0);
            const activeChild = item.children?.find((c) => isPathMatching(pathname, c.href));
            const branchHasActive = selfActive || Boolean(activeChild);
            const isBranchOpen = Boolean(openBranches[item.href] ?? true);

            return (
              <div key={item.href} className="flex flex-col">
                <div className="flex items-center gap-0.5">
                  <Link
                    href={item.href}
                    onClick={onNavigate}
                    aria-current={selfActive ? "page" : undefined}
                    title={collapsed ? (item.desc ? `${item.label} — ${item.desc}` : item.label) : item.desc}
                    className={cn(
                      "flex min-h-[42px] flex-1 items-center gap-2.5 rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
                      selfActive
                        ? "border-l-4 border-brand bg-brand/10 font-semibold text-brand"
                        : branchHasActive
                          ? "bg-surface text-brand font-semibold"
                          : "text-ink hover:bg-surface",
                      collapsed && "justify-center px-0",
                    )}
                  >
                    <Icon className="size-4 shrink-0" aria-hidden />
                    {!collapsed && <span className="truncate">{item.label}</span>}
                  </Link>

                  {!collapsed && hasChildren && (
                    <button
                      type="button"
                      onClick={() => toggleBranch(item.href)}
                      aria-expanded={isBranchOpen}
                      aria-label={
                        isBranchOpen
                          ? `Thu gọn nhánh ${item.label}`
                          : `Mở rộng nhánh ${item.label}`
                      }
                      title={isBranchOpen ? "Thu gọn nhánh con" : "Mở rộng nhánh con"}
                      className="flex size-8 shrink-0 items-center justify-center rounded-md text-ink-muted transition-colors hover:bg-surface hover:text-ink"
                    >
                      {isBranchOpen ? (
                        <ChevronDown className="size-4" aria-hidden />
                      ) : (
                        <ChevronRight className="size-4" aria-hidden />
                      )}
                    </button>
                  )}
                </div>

                {!collapsed && hasChildren && isBranchOpen && (
                  <ul
                    aria-label={`Nhánh con ${item.label}`}
                    className="ml-5 mt-1 flex flex-col gap-0.5 border-l-2 border-border pl-2.5"
                  >
                    {item.children!.map((child) => {
                      const ChildIcon = child.icon;
                      const childActive = isPathMatching(pathname, child.href);
                      return (
                        <li key={child.href}>
                          <Link
                            href={child.href}
                            onClick={onNavigate}
                            aria-current={childActive ? "page" : undefined}
                            title={child.desc}
                            className={cn(
                              "flex min-h-[36px] items-center gap-2 rounded-md px-2.5 py-1 text-xs font-medium transition-colors",
                              childActive
                                ? "bg-brand/10 font-semibold text-brand"
                                : "text-ink-muted hover:bg-surface hover:text-ink",
                            )}
                          >
                            <ChildIcon className="size-3.5 shrink-0" aria-hidden />
                            <span className="truncate">{child.label}</span>
                          </Link>
                        </li>
                      );
                    })}
                  </ul>
                )}
              </div>
            );
          })}
        </div>
      ))}
    </nav>
  );
}

/** A-C01 — sidebar + top header + content shell. Collapse is in-memory (KISS). */
export function AdminShell({ children }: { children: React.ReactNode }) {
  return <SessionBootstrap>{(user) => <Shell user={user}>{children}</Shell>}</SessionBootstrap>;
}

function Shell({ user, children }: { user: UserProfileDto; children: React.ReactNode }) {
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const logout = useLogout();

  const userBlock = (
    <div className="flex items-center gap-3 border-t border-border p-3">
      <div className="flex size-9 shrink-0 items-center justify-center rounded-full bg-brand font-semibold text-white">
        {user.displayName?.charAt(0)?.toUpperCase() ?? "A"}
      </div>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium text-ink">{user.displayName}</p>
        <p className="text-xs text-ink-muted">Quản trị nội dung</p>
      </div>
      <button
        type="button"
        onClick={() => logout.mutate()}
        aria-label="Đăng xuất"
        title="Đăng xuất"
        className="flex size-10 items-center justify-center rounded-md text-ink-muted hover:bg-surface-alt hover:text-error"
      >
        <LogOut className="size-5" aria-hidden />
      </button>
    </div>
  );

  return (
    <div className="flex min-h-screen bg-surface">
      {/* Desktop sidebar */}
      <aside
        className={cn(
          "sticky top-0 hidden h-screen flex-col border-r-2 border-border bg-surface-alt transition-all md:flex",
          collapsed ? "w-16" : "w-60",
        )}
      >
        <div className={cn("flex min-h-14 items-center border-b border-border py-2", collapsed ? "justify-center px-2" : "justify-between px-3")}>
          <Link href="/dashboard" className="flex min-w-0 items-center gap-2" title="Dấu Việt — trang quản trị">
            {collapsed ? (
              /* eslint-disable-next-line @next/next/no-img-element -- logo là file tĩnh trong /public */
              <img src="/logo-seal.svg" alt="Dấu Việt" className="size-8 shrink-0 object-contain" />
            ) : (
              /* eslint-disable-next-line @next/next/no-img-element -- logo là file tĩnh trong /public */
              <img src="/logo.svg" alt="Dấu Việt" className="h-9 w-auto max-w-[168px] object-contain" />
            )}
          </Link>
          {!collapsed && (
            <button
              type="button"
              onClick={() => setCollapsed((c) => !c)}
              aria-expanded={!collapsed}
              aria-label={collapsed ? "Mở rộng thanh bên" : "Thu gọn thanh bên"}
              className="flex size-10 items-center justify-center rounded-md text-ink-muted hover:bg-surface-alt"
            >
              {collapsed ? (
                <PanelLeftOpen className="size-5" aria-hidden />
              ) : (
                <PanelLeftClose className="size-5" aria-hidden />
              )}
            </button>
          )}
        </div>
        <div className="flex-1 overflow-y-auto">
          <NavLinks collapsed={collapsed} />
        </div>
        {collapsed ? (
          <div className="flex justify-center border-t border-border p-2">
            <button
              type="button"
              onClick={() => logout.mutate()}
              aria-label="Đăng xuất"
              className="flex size-10 items-center justify-center rounded-md text-ink-muted hover:bg-surface-alt hover:text-error"
            >
              <LogOut className="size-5" aria-hidden />
            </button>
          </div>
        ) : (
          userBlock
        )}
      </aside>

      {/* Mobile drawer */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 md:hidden">
          <div
            className="absolute inset-0 bg-black/40"
            onClick={() => setMobileOpen(false)}
            aria-hidden
          />
          <div className="absolute left-0 top-0 flex h-full w-64 flex-col bg-surface-alt shadow-lg">
            <div className="flex min-h-14 items-center gap-2 border-b border-border px-4 py-2">
              {/* eslint-disable-next-line @next/next/no-img-element -- logo là file tĩnh trong /public */}
              <img src="/logo.svg" alt="Dấu Việt" className="h-9 w-auto max-w-[180px] object-contain" />
            </div>
            <div className="flex-1 overflow-y-auto">
              <NavLinks collapsed={false} onNavigate={() => setMobileOpen(false)} />
            </div>
            {userBlock}
          </div>
        </div>
      )}

      {/* Main column */}
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-40 flex h-14 items-center gap-3 border-b-4 border-heading bg-surface px-4">
          <button
            type="button"
            onClick={() => setMobileOpen(true)}
            aria-label="Mở menu điều hướng"
            className="flex size-10 items-center justify-center rounded-md text-ink hover:bg-surface-alt md:hidden"
          >
            <Menu className="size-5" aria-hidden />
          </button>
          {/* eslint-disable-next-line @next/next/no-img-element -- logo là file tĩnh trong /public */}
          <img src="/logo-seal.svg" alt="Dấu Việt" className="size-7 shrink-0 object-contain md:hidden" />
          <Breadcrumbs />
        </header>
        <main className="flex-1 p-4 md:p-6">{children}</main>
      </div>
    </div>
  );
}
