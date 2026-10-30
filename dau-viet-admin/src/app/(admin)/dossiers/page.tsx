import Link from "next/link";

import { PageGuideBanner } from "@/components/page-guide-banner";
import { PageHeader } from "@/components/page-header";
import { WorkspaceHubTabs } from "@/components/workspace-hub-tabs";
import { Button } from "@/components/ui/button";
import { DossiersTable } from "@/features/dossiers/dossiers-table";

export const metadata = { title: "Hồ sơ lịch sử — Dấu Việt CMS" };

export default function DossiersPage() {
  return (
    <div>
      <WorkspaceHubTabs hub="event-children" />
      <PageHeader
        eyebrow="QUẢN TRỊ · NHÁNH CON SỰ KIỆN · HỒ SƠ LỊCH SỬ"
        title="Hồ sơ lịch sử"
        description="Thư viện nhân vật, địa điểm, hiện vật và bối cảnh — liên kết vào sự kiện để học viên mở khóa."
        actions={
          <Button asChild>
            <Link href="/dossiers/new">+ Tạo hồ sơ</Link>
          </Button>
        }
      />
      <PageGuideBanner
        storageKey="dossiers"
        title="Hồ sơ lịch sử"
        purpose="Biên soạn thẻ tri thức chuyên sâu (Nhân vật, Địa điểm, Hiện vật, Bối cảnh) để trao thưởng khi học viên hoàn thành bài học trong Sự kiện."
        appSurface="Hiển thị trong tab Sưu tập (Collection) và màn Kết quả bài học của học viên."
        nextStep="Sau khi xuất bản Hồ sơ, hãy vào tab Gamification của Sự kiện để gắn Hồ sơ vào danh sách mở khóa."
        links={[{ href: "/events", label: "Gắn Hồ sơ vào Sự kiện" }]}
      />
      <DossiersTable />
    </div>
  );
}
