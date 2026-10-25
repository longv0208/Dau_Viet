import { PageHeader } from "@/components/page-header";
import { DossierDetail } from "@/features/dossiers/dossier-detail";

export const metadata = { title: "Hồ sơ — Dấu Việt CMS" };

export default async function DossierPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return (
    <div>
      <PageHeader title="Hồ sơ lịch sử" />
      <DossierDetail id={id} />
    </div>
  );
}
