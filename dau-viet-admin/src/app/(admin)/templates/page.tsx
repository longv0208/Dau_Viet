import Link from "next/link";

import { PageGuideBanner } from "@/components/page-guide-banner";
import { PageHeader } from "@/components/page-header";
import { WorkspaceHubTabs } from "@/components/workspace-hub-tabs";
import { Button } from "@/components/ui/button";
import { TemplatesTable } from "@/features/templates/templates-table";

export const metadata = { title: "Mẫu bài học — Dấu Việt CMS" };

export default function TemplatesPage() {
  return (
  <div>
      <WorkspaceHubTabs hub="event-children" />
      <PageHeader
        eyebrow="QUẢN TRỊ · NHÁNH CON SỰ KIỆN · MẪU BÀI HỌC"
        title="Mẫu bài học"
        description="Khung giai đoạn và hoạt động chuẩn dùng để khởi tạo bài học mới nhanh chóng."
        actions={
          <Button asChild>
            <Link href="/templates/new">+ Tạo khung bài học</Link>
          </Button>
        }
      />
      <PageGuideBanner
        storageKey="templates"
        title="Mẫu bài học"
        purpose="Định nghĩa cấu trúc các chặng tư duy và loại hoạt động mặc định khi quản trị viên tạo bài học mới."
        appSurface="Quy định bố cục các bước tiến trình trên thanh StepProgressBar của Sổ tay Thám tử Lịch sử."
        nextStep="Chọn mẫu phù hợp khi tạo Bài học mới trong Sự kiện."
        links={[{ href: "/lessons/new", label: "+ Tạo bài học từ mẫu" }]}
      />
      <TemplatesTable />
    </div>
  );
}
