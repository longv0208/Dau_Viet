import Link from "next/link";

import { PageGuideBanner } from "@/components/page-guide-banner";
import { PageHeader } from "@/components/page-header";
import { WorkspaceHubTabs } from "@/components/workspace-hub-tabs";
import { Button } from "@/components/ui/button";
import { EvidenceTable } from "@/features/evidence/evidence-table";

export const metadata = { title: "Bằng chứng lịch sử — Dấu Việt CMS" };

export default function EvidencePage() {
  return (
    <div>
      <WorkspaceHubTabs hub="event-children" />
      <PageHeader
        eyebrow="QUẢN TRỊ · NHÁNH CON SỰ KIỆN · BẰNG CHỨNG"
        title="Bằng chứng lịch sử"
        description="Quản lý các tư liệu nguồn dùng để chứng thực và suy luận trong bài học."
        actions={
          <Button asChild>
            <Link href="/evidence/new">+ Tạo bằng chứng</Link>
          </Button>
        }
      />
      <PageGuideBanner
        storageKey="evidence"
        title="Bằng chứng lịch sử"
        purpose="Lưu trữ tư liệu, trích dẫn sử liệu, bản đồ và hiện vật gắn với từng Sự kiện để học viên thu thập và kiểm chứng giả thuyết."
        appSurface="Hiển thị thành Thẻ Manh mối (Clue Cards) trong bài học và lưu vào bộ sưu tập Dấu Vết của học viên."
        nextStep="Đảm bảo bằng chứng có đầy đủ Nguồn trích dẫn và chuyển trạng thái Phê duyệt trước khi gắn vào Bài học."
        links={[
          { href: "/events", label: "Không gian Sự kiện" },
          { href: "/dossiers", label: "Hồ sơ lịch sử" },
        ]}
      />
      <EvidenceTable />
    </div>
  );
}
