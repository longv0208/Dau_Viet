import { Suspense } from "react";

import { PageHeader } from "@/components/page-header";
import { EvidenceForm } from "@/features/evidence/evidence-form";
import { Skeleton } from "@/components/ui/skeleton";

export const metadata = { title: "Tạo bằng chứng — Dấu Việt CMS" };

/**
 * ?event=<uuid> pre-fills the event (workspace context); ?return=<path>
 * sends the admin back to the workspace tab after save.
 */
export default function NewEvidencePage() {
  return (
    <div>
      <PageHeader
        title="Tạo bằng chứng"
        description="Thêm một bằng chứng lịch sử có nguồn trích dẫn vào hệ thống."
      />
      <Suspense fallback={<Skeleton className="h-96 w-full" />}>
        <EvidenceForm />
      </Suspense>
    </div>
  );
}
