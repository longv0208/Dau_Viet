import Link from "next/link";

import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { EvidenceTable } from "@/features/evidence/evidence-table";

export const metadata = { title: "Bằng chứng lịch sử — Dấu Việt CMS" };

export default function EvidencePage() {
  return (
    <div>
      <PageHeader
        eyebrow="QUẢN TRỊ · BẰNG CHỨNG"
        title="Bằng chứng lịch sử"
        description="Quản lý các tư liệu nguồn dùng để chứng thực nội dung bài học."
        actions={
          <Button asChild>
            <Link href="/evidence/new">Tạo bằng chứng</Link>
          </Button>
        }
      />
      <EvidenceTable />
    </div>
  );
}
