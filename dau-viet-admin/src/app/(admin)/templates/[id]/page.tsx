import { Suspense } from "react";

import { PageHeader } from "@/components/page-header";
import { TemplateForm } from "@/features/templates/template-form";

export const metadata = { title: "Sửa khung bài học — Dấu Việt CMS" };

export default async function EditTemplatePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return (
    <div>
      <PageHeader
        eyebrow="QUẢN TRỊ · MẪU BÀI HỌC"
        title="Sửa khung bài học"
        description="Chỉnh sửa thông tin và danh sách giai đoạn của khung."
      />
      <Suspense>
        <TemplateForm templateId={id} />
      </Suspense>
    </div>
  );
}
