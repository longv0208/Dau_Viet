import { PageHeader } from "@/components/page-header";
import { EvidenceEditorPage } from "@/features/evidence/evidence-editor-page";

export const metadata = { title: "Chỉnh sửa bằng chứng — Dấu Việt CMS" };

export default async function EvidenceDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return (
    <div>
      <PageHeader
        title="Bằng chứng"
        description="Xem và chỉnh sửa thông tin bằng chứng lịch sử."
      />
      <EvidenceEditorPage evidenceId={id} />
    </div>
  );
}
