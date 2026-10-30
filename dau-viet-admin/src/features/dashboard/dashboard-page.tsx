"use client";

import { useQuery } from "@tanstack/react-query";
import {
  BookOpen,
  Calendar,
  Compass,
  Gift,
  Image as ImageIcon,
  Route,
} from "lucide-react";
import Link from "next/link";

import { apiFetch } from "@/lib/api-client";
import type { UserProfileDto } from "@/lib/dto/user";
import { qk } from "@/lib/query-keys";
import { PaperCard } from "@/components/atoms/paper-card";
import { SectionDivider } from "@/components/atoms/section-divider";
import { StampSeal } from "@/components/atoms/stamp-seal";
import { PageHeader } from "@/components/page-header";
import { Skeleton } from "@/components/ui/skeleton";

import { AdminPingCard } from "./admin-ping-card";
import { OnboardingWorkflowCard } from "./onboarding-workflow-card";
import { RecentLessonsCard } from "./recent-lessons-card";

const QUICK_NAV = [
  { href: "/events", label: "Sự kiện & Không gian biên tập", icon: Calendar, desc: "Quản lý sự kiện, bài học, bằng chứng, hoạt họa" },
  { href: "/learning-path", label: "Bản đồ Dấu Ấn", icon: Route, desc: "Cấu hình lộ trình học theo Thời kỳ" },
  { href: "/lessons", label: "Danh sách Bài học", icon: BookOpen, desc: "Tra cứu và xuất bản toàn bộ bài học" },
  { href: "/items", label: "Vật phẩm thưởng", icon: Gift, desc: "Mô hình, huy hiệu & điều kiện mở khóa" },
  { href: "/island-builder", label: "Đảo Di Sản & Cửa hàng", icon: Compass, desc: "Thiết kế đảo 2.5D và vật phẩm bán trong Shop" },
  { href: "/assets", label: "Thư viện media", icon: ImageIcon, desc: "Kho hình ảnh và tệp dùng chung" },
];

/** A-02 — welcome + 4-step onboarding workflow + backend ping + quick nav + recent lessons. */
export function DashboardPage() {
  const me = useQuery({ queryKey: qk.me(), queryFn: () => apiFetch<UserProfileDto>("/users/me") });

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        eyebrow="QUẢN TRỊ · TỔNG QUAN"
        title="Tổng quan & Hướng dẫn bắt đầu"
        description="Trung tâm điều phối nội dung lịch sử, học liệu, lộ trình Bản đồ Dấu Ấn và hệ thống phần thưởng."
      />

      <PaperCard className="p-5">
        <div className="flex items-center justify-between gap-4">
          {me.isPending ? (
            <Skeleton className="h-12 w-full max-w-xs" />
          ) : (
            <>
              <div className="flex items-center gap-4">
                <div className="flex size-12 items-center justify-center rounded-full border-2 border-heading bg-brand text-lg font-semibold text-surface-alt shadow-pixel-sm">
                  {me.data?.displayName?.charAt(0)?.toUpperCase() ?? "A"}
                </div>
                <div>
                  <p className="font-display text-lg font-semibold text-ink">
                    Xin chào, {me.data?.displayName ?? "bạn"}
                  </p>
                  <p className="text-sm text-ink-muted">Quản trị nội dung</p>
                </div>
              </div>
              <StampSeal variant="outline" label="QUẢN TRỊ" className="hidden sm:inline-flex" />
            </>
          )}
        </div>
      </PaperCard>
      <OnboardingWorkflowCard />

      <div className="grid gap-4 md:grid-cols-2">
        <AdminPingCard />
        <PaperCard className="p-5">
          <SectionDivider
            eyebrow="ĐIỀU HƯỚNG"
            eyebrowColor="jade"
            title="Truy cập nhanh"
            className="mb-4"
          />
          <ul className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
            {QUICK_NAV.map((item, idx) => {
              const Icon = item.icon;
              return (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    className="flex items-center gap-3 rounded-md border border-border bg-surface p-3 transition-all hover:-translate-y-0.5 hover:border-brand hover:bg-surface-alt hover:shadow-pixel-sm"
                  >
                    <Icon
                      className={idx % 2 === 0 ? "size-5 shrink-0 text-brand" : "size-5 shrink-0 text-jade"}
                      aria-hidden
                    />
                    <span className="min-w-0 flex-1">
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
        </PaperCard>
      </div>

      <RecentLessonsCard />
    </div>
  );
}
