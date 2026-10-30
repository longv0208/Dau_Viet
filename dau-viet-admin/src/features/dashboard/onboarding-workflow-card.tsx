"use client";

import {
  ArrowRight,
  BookOpen,
  Calendar,
  FileText,
  Route,
  Sparkles,
} from "lucide-react";
import Link from "next/link";

import { ChapterBadge } from "@/components/atoms/chapter-badge";
import { PaperCard } from "@/components/atoms/paper-card";
import { SectionDivider } from "@/components/atoms/section-divider";
import { Button } from "@/components/ui/button";

interface WorkflowStep {
  stepNo: string;
  title: string;
  subtitle: string;
  description: string;
  learnerImpact: string;
  primaryAction: { href: string; label: string };
  secondaryLinks: { href: string; label: string }[];
  icon: React.ComponentType<{ className?: string }>;
}

const WORKFLOW_STEPS: WorkflowStep[] = [
  {
    stepNo: "01",
    title: "Bước 1: Tạo Sự kiện & Địa điểm lịch sử",
    subtitle: "Khởi tạo không gian sự kiện gốc",
    description:
      "Tạo sự kiện lịch sử (thời kỳ, năm diễn ra, câu hỏi điều tra trung tâm) và ghim tọa độ địa điểm di tích liên quan.",
    learnerImpact: "Hiển thị thành mốc sự kiện trên Hành trình Lịch sử (/journey) và Bản đồ di tích (/map).",
    primaryAction: { href: "/events", label: "Mở danh sách Sự kiện" },
    secondaryLinks: [
      { href: "/events/new", label: "+ Tạo sự kiện mới" },
      { href: "/map-locations", label: "Địa điểm di tích" },
    ],
    icon: Calendar,
  },
  {
    stepNo: "02",
    title: "Bước 2: Chuẩn bị Tư liệu, Bằng chứng & Hồ sơ",
    subtitle: "Xây dựng kho học liệu cho sự kiện",
    description:
      "Tải ảnh minh họa, hoạt họa HTML tương tác, biên tập các Bằng chứng nguồn có trích dẫn và thẻ Hồ sơ lịch sử (nhân vật, hiện vật).",
    learnerImpact: "Hiển thị trong thẻ manh mối bài học và Kho Sưu tập của học viên.",
    primaryAction: { href: "/evidence", label: "Quản lý Bằng chứng" },
    secondaryLinks: [
      { href: "/dossiers", label: "Hồ sơ lịch sử" },
      { href: "/assets", label: "Thư viện Media" },
      { href: "/animations", label: "Hoạt họa HTML" },
    ],
    icon: FileText,
  },
  {
    stepNo: "03",
    title: "Bước 3: Soạn Bài học & Gắn phần thưởng mở khóa",
    subtitle: "Thiết kế 4 giai đoạn điều tra & vật phẩm",
    description:
      "Soạn kịch bản bài học (Bối cảnh → Khám phá → Suy luận → Kết luận CER) trong Không gian Sự kiện và gắn Điều kiện mở khóa Vật phẩm thưởng.",
    learnerImpact: "Học viên trải nghiệm trong Sổ tay Thám tử Lịch sử và nhận vật phẩm khi hoàn thành.",
    primaryAction: { href: "/lessons", label: "Soạn & quản lý Bài học" },
    secondaryLinks: [
      { href: "/items", label: "Cấu hình Vật phẩm thưởng" },
      { href: "/templates", label: "Mẫu bài học" },
    ],
    icon: BookOpen,
  },
  {
    stepNo: "04",
    title: "Bước 4: Đưa vào Bản đồ Dấu Ấn & Xuất bản",
    subtitle: "Sắp xếp lộ trình & phát hành",
    description:
      "Xuất bản phiên bản bất biến cho bài học/sự kiện, sau đó xếp sự kiện vào đúng Chương Thời kỳ trên Bản đồ Dấu Ấn để học viên bắt đầu học.",
    learnerImpact: "Mở khóa tuần tự theo từng Thời kỳ trên ứng dụng của học viên.",
    primaryAction: { href: "/learning-path", label: "Cấu hình Bản đồ Dấu Ấn" },
    secondaryLinks: [
      { href: "/island-builder", label: "Đảo Di Sản & Cửa hàng" },
      { href: "/versions", label: "Kiểm tra Phiên bản" },
    ],
    icon: Route,
  },
];

/**
 * Hướng dẫn quy trình biên tập 4 bước dành cho quản trị viên mới trên /dashboard (AC-3).
 */
export function OnboardingWorkflowCard() {
  return (
    <PaperCard className="border-2 border-heading p-5">
      <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
        <SectionDivider
          eyebrow="HƯỚNG DẪN BẮT ĐẦU DÀNH CHO NGƯỜI MỚI"
          eyebrowColor="brand"
          title="Quy trình Biên tập Nội dung 4 Bước"
          description="Bạn mới vào hệ thống? Hãy đi theo đúng 4 bước dưới đây để tạo một sự kiện và bài học lịch sử hoàn chỉnh từ con số 0."
          className="flex-1"
        />
        <Button asChild size="sm">
          <Link href="/events/new">
            <Sparkles className="mr-1.5 size-4" aria-hidden />
            Bắt đầu tạo Sự kiện đầu tiên
          </Link>
        </Button>
      </div>

      <ol className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {WORKFLOW_STEPS.map((step) => {
          const Icon = step.icon;
          return (
            <li
              key={step.stepNo}
              className="flex flex-col justify-between rounded-lg border border-border bg-surface p-4 shadow-sm transition-all hover:border-brand/60"
            >
              <div>
                <div className="mb-3 flex items-center justify-between gap-2">
                  <ChapterBadge label={step.stepNo} size={32} filled />
                  <span className="inline-flex items-center gap-1 rounded-full bg-surface-alt px-2.5 py-0.5 text-[11px] font-semibold text-jade-dark border border-border">
                    <Icon className="size-3.5 text-brand" aria-hidden />
                    {step.subtitle}
                  </span>
                </div>

                <h3 className="font-display text-base font-bold text-ink">
                  {step.title}
                </h3>
                <p className="mt-1.5 text-xs leading-relaxed text-ink-secondary">
                  {step.description}
                </p>

                <div className="mt-2.5 rounded-md border border-dashed border-border bg-surface-alt px-2.5 py-1.5 text-[11px] text-ink-muted">
                  <strong className="font-semibold text-ink">Trên ứng dụng:</strong>{" "}
                  {step.learnerImpact}
                </div>
              </div>

              <div className="mt-4 flex flex-col gap-2 border-t border-border pt-3">
                <Link
                  href={step.primaryAction.href}
                  className="inline-flex items-center justify-between rounded-md bg-brand/10 px-3 py-1.5 text-xs font-bold text-brand transition-colors hover:bg-brand hover:text-surface-alt"
                >
                  <span>{step.primaryAction.label}</span>
                  <ArrowRight className="size-3.5 shrink-0" aria-hidden />
                </Link>
                <div className="flex flex-wrap gap-x-3 gap-y-1 px-1">
                  {step.secondaryLinks.map((sec) => (
                    <Link
                      key={sec.href}
                      href={sec.href}
                      className="text-[11px] font-medium text-ink-muted hover:text-brand hover:underline"
                    >
                      {sec.label}
                    </Link>
                  ))}
                </div>
              </div>
            </li>
          );
        })}
      </ol>
    </PaperCard>
  );
}
