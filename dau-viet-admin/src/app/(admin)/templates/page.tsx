import Link from "next/link";

import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { TemplatesTable } from "@/features/templates/templates-table";

export const metadata = { title: "Mẫu bài học — Dấu Việt CMS" };

export default function TemplatesPage() {
  return (
    <div>
      <PageHeader
        eyebrow="QUẢN TRỊ · MẪU BÀI HỌC"
        title="Mẫu bài học"
        description="Khung hoạt động chuẩn dùng để soạn bài học."
        actions={
          <Button asChild>
            <Link href="/templates/new">+ Tạo khung bài học</Link>
          </Button>
        }
      />
      <TemplatesTable />
    </div>
  );
}
