import { PageHeader } from "@/components/page-header";
import { DossierCreateForm } from "@/features/dossiers/dossier-create-form";

export const metadata = { title: "Tạo hồ sơ — Dấu Việt CMS" };

export default function NewDossierPage() {
  return (
    <div>
      <PageHeader
        title="Tạo hồ sơ lịch sử"
        description="Hồ sơ mới ở trạng thái bản nháp — xuất bản sau khi kiểm duyệt nguồn."
      />
      <DossierCreateForm />
    </div>
  );
}
