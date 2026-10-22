"use client";

import {
  BookOpen,
  Calendar,
  FileText,
  Gift,
  History,
  Image as ImageIcon,
  LayoutDashboard,
  LayoutTemplate,
  LogOut,
  Menu,
  PanelLeftClose,
  PanelLeftOpen,
} from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";

import { cn } from "@/lib/utils";
import type { UserProfileDto } from "@/lib/dto/user";
import { useLogout } from "@/features/auth/use-auth";
import { SessionBootstrap } from "@/features/auth/session-bootstrap";

import { Breadcrumbs } from "./breadcrumbs";

const NAV_ITEMS = [
  { href: "/dashboard", label: "Tổng quan", icon: LayoutDashboard },
  { href: "/events", label: "Sự kiện", icon: Calendar },
  { href: "/lessons", label: "Bài học", icon: BookOpen },
  { href: "/evidence", label: "Bằng chứng", icon: FileText },
  { href: "/templates", label: "Mẫu bài học", icon: LayoutTemplate },
  { href: "/assets", label: "Thư viện media", icon: ImageIcon },
  { href: "/versions", label: "Phiên bản", icon: History },
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
        <div className="flex h-14 items-center justify-between border-b border-border px-3">
          {!collapsed && (
            <Link href="/dashboard" className="font-display text-lg font-bold text-brand">
              Dấu Việt
            </Link>
          )}
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
            <div className="flex h-14 items-center border-b border-border px-4">
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
