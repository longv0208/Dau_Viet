"use client";

import {
  BookMarked,
  BookOpen,
  Calendar,
  FileText,
  Film,
  Gift,
  History,
  Image as ImageIcon,
  LayoutDashboard,
  LayoutTemplate,
  LogOut,
  Menu,
  PanelLeftClose,
  PanelLeftOpen,
  Route,
} from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";

import { cn } from "@/lib/utils";
import type { UserProfileDto } from "@/lib/dto/user";
import { useLogout } from "@/features/auth/use-auth";
import { SessionBootstrap } from "@/features/auth/session-bootstrap";

import { Breadcrumbs } from "./breadcrumbs";

// Sự kiện là điểm vào chính — Event Workspace gom bài học/bằng chứng/hoạt họa
// theo sự kiện. Các mục còn lại là thư viện dùng chung toàn hệ thống.
const NAV_ITEMS = [
  { href: "/dashboard", label: "Tổng quan", icon: LayoutDashboard },
  { href: "/events", label: "Sự kiện", icon: Calendar },
  { href: "/learning-path", label: "Bản đồ Dấu Ấn", icon: Route },
  { href: "/templates", label: "Mẫu bài học", icon: LayoutTemplate },
  { href: "/assets", label: "Thư viện media", icon: ImageIcon },
  { href: "/animations", label: "Hoạt họa lịch sử", icon: Film },
  { href: "/lessons", label: "Bài học", icon: BookOpen },
  { href: "/evidence", label: "Bằng chứng", icon: FileText },
  { href: "/versions", label: "Phiên bản", icon: History },
  { href: "/dossiers", label: "Hồ sơ lịch sử", icon: BookMarked },
  { href: "/items", label: "Vật phẩm thưởng", icon: Gift },
];

function NavLinks({ collapsed, onNavigate }: { collapsed: boolean; onNavigate?: () => void }) {
  const pathname = usePathname();
  return (
    <nav aria-label="Điều hướng chính" className="flex flex-col gap-1 p-2">
      {NAV_ITEMS.map((item) => {
        const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
        const Icon = item.icon;
        return (
          <Link
            key={item.href}
            href={item.href}
            onClick={onNavigate}
            aria-current={active ? "page" : undefined}
            title={collapsed ? item.label : undefined}
            className={cn(
              "flex min-h-[44px] items-center gap-3 rounded-md px-3 text-sm font-medium transition-colors",
              active ? "bg-brand text-white" : "text-ink hover:bg-surface-alt",
              collapsed && "justify-center px-0",
            )}
          >
            <Icon className="size-5 shrink-0" aria-hidden />
            {!collapsed && item.label}
          </Link>
        );
      })}
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
          "sticky top-0 hidden h-screen flex-col border-r border-border bg-white transition-all md:flex",
          collapsed ? "w-16" : "w-60",
        )}
      >
        <div className={cn("flex h-14 items-center border-b border-border", collapsed ? "justify-center px-2" : "justify-between px-3")}>
          <Link href="/dashboard" className="flex min-w-0 items-center gap-2" title="Dấu Việt — trang quản trị">
            {/* eslint-disable-next-line @next/next/no-img-element -- logo là file tĩnh trong /public */}
            <img src="/logo.svg" alt="Dấu Việt" className="size-8 shrink-0 rounded-full object-cover" />
            {!collapsed && (
              <span className="truncate font-display text-lg font-bold text-brand">Dấu Việt</span>
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
          <div className="absolute left-0 top-0 flex h-full w-64 flex-col bg-white shadow-lg">
            <div className="flex h-14 items-center gap-2 border-b border-border px-4">
              {/* eslint-disable-next-line @next/next/no-img-element -- logo là file tĩnh trong /public */}
              <img src="/logo.svg" alt="" className="size-8 rounded-full object-cover" />
              <span className="font-display text-lg font-bold text-brand">Dấu Việt</span>
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
        <header className="sticky top-0 z-40 flex h-14 items-center gap-3 border-b border-border bg-white px-4">
          <button
            type="button"
            onClick={() => setMobileOpen(true)}
            aria-label="Mở menu điều hướng"
            className="flex size-10 items-center justify-center rounded-md text-ink hover:bg-surface-alt md:hidden"
          >
            <Menu className="size-5" aria-hidden />
          </button>
          <Breadcrumbs />
        </header>
        <main className="flex-1 p-4 md:p-6">{children}</main>
      </div>
    </div>
  );
}
