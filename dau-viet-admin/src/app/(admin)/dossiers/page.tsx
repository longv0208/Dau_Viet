import Link from "next/link";

import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { DossiersTable } from "@/features/dossiers/dossiers-table";

export const metadata = { title: "Hồ sơ lịch sử — Dấu Việt CMS" };

export default function DossiersPage() {
  return (
    <div>
      <PageHeader
        eyebrow="QUẢN TRỊ · HỒ SƠ LỊCH SỬ"
        title="Hồ sơ lịch sử"
        description="Thư viện nhân vật, địa điểm, hiện vật và bối cảnh — liên kết vào sự kiện để learner mở khoá."
        actions={
          <Button asChild>
            <Link href="/dossiers/new">Tạo hồ sơ</Link>
          </Button>
        }
      />
      <DossiersTable />
    </div>
  );
}
