import { PageHeader } from "@/components/page-header";
import { EvidenceForm } from "@/features/evidence/evidence-form";

export const metadata = { title: "Tạo bằng chứng — Dấu Việt CMS" };

export default function NewEvidencePage() {
  return (
    <div>
      <PageHeader
        title="Tạo bằng chứng"
        description="Thêm một bằng chứng lịch sử có nguồn trích dẫn vào hệ thống."
      />
      <EvidenceForm />
    </div>
  );
}
