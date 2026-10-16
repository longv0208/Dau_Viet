import { PageHeader } from "@/components/page-header";
import { TemplatesTable } from "@/features/templates/templates-table";

export const metadata = { title: "Mẫu bài học — Dấu Việt CMS" };

export default function TemplatesPage() {
  return (
    <div>
      <PageHeader
        title="Mẫu bài học"
        description="Khung hoạt động chuẩn dùng để soạn bài học. Chỉ xem."
      />
      <TemplatesTable />
    </div>
  );
}
