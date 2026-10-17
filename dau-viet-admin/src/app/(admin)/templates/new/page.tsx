import { Suspense } from "react";

import { PageHeader } from "@/components/page-header";
import { TemplateForm } from "@/features/templates/template-form";

export const metadata = { title: "Tạo khung bài học — Dấu Việt CMS" };

export default function NewTemplatePage() {
  return (
    <div>
      <PageHeader
        title="Tạo khung bài học"
        description="Định nghĩa một khung giai đoạn dùng lại được cho nhiều bài học."
      />
      <Suspense>
        <TemplateForm />
      </Suspense>
    </div>
  );
}
