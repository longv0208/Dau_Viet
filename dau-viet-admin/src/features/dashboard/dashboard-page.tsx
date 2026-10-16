"use client";

import { useQuery } from "@tanstack/react-query";
import {
  BookOpen,
  Calendar,
  History,
  Image as ImageIcon,
  LayoutTemplate,
} from "lucide-react";
import Link from "next/link";

import { apiFetch } from "@/lib/api-client";
import type { UserProfileDto } from "@/lib/dto/user";
import { qk } from "@/lib/query-keys";
import { PageHeader } from "@/components/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

import { AdminPingCard } from "./admin-ping-card";
import { RecentLessonsCard } from "./recent-lessons-card";

const QUICK_NAV = [
  { href: "/events", label: "Sự kiện", icon: Calendar, desc: "Quản lý sự kiện lịch sử" },
  { href: "/lessons", label: "Bài học", icon: BookOpen, desc: "Soạn và xuất bản bài học" },
  { href: "/templates", label: "Mẫu bài học", icon: LayoutTemplate, desc: "Khung hoạt động chuẩn" },
  { href: "/assets", label: "Thư viện media", icon: ImageIcon, desc: "Hình ảnh và tư liệu" },
  { href: "/versions", label: "Phiên bản", icon: History, desc: "Lịch sử xuất bản bài học" },
];

/** A-02 — welcome + backend ping + quick nav + recent lessons. No fake metrics. */
export function DashboardPage() {
  const me = useQuery({ queryKey: qk.me(), queryFn: () => apiFetch<UserProfileDto>("/users/me") });

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Tổng quan" />

      <Card>
        <CardContent className="flex items-center gap-4 py-5">
          {me.isPending ? (
            <Skeleton className="h-12 w-full max-w-xs" />
          ) : (
            <>
              <div className="flex size-12 items-center justify-center rounded-full bg-brand text-lg font-semibold text-white">
                {me.data?.displayName?.charAt(0)?.toUpperCase() ?? "A"}
              </div>
              <div>
                <p className="font-display text-lg font-semibold text-ink">
                  Xin chào, {me.data?.displayName ?? "bạn"}
                </p>
                <p className="text-sm text-ink-muted">Quản trị nội dung</p>
              </div>
            </>
          )}
        </CardContent>
      </Card>

      <div className="grid gap-4 md:grid-cols-2">
        <AdminPingCard />
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Truy cập nhanh</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="grid grid-cols-1 gap-2 sm:grid-cols-2">
              {QUICK_NAV.map((item) => {
                const Icon = item.icon;
                return (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      className="flex items-center gap-3 rounded-md border border-border p-3 transition-colors hover:border-brand hover:bg-surface-alt"
                    >
                      <Icon className="size-5 shrink-0 text-brand" aria-hidden />
                      <span className="min-w-0">
                        <span className="block truncate text-sm font-medium text-ink">
                          {item.label}
                        </span>
                        <span className="block truncate text-xs text-ink-muted">
                          {item.desc}
                        </span>
                      </span>
                    </Link>
                  </li>
                );
              })}
            </ul>
          </CardContent>
        </Card>
      </div>

      <RecentLessonsCard />
    </div>
  );
}
