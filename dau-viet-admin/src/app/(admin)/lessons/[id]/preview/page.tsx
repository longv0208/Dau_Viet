import { Suspense } from "react";

import { PageHeader } from "@/components/page-header";
import { PreviewPage } from "@/features/lessons/preview/preview-page";
import { Skeleton } from "@/components/ui/skeleton";

export const metadata = { title: "Xem trước — Dấu Việt CMS" };

export default async function LessonPreviewRoute({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return (
    <div>
      <PageHeader
        eyebrow="QUẢN TRỊ · XEM TRƯỚC"
        title="Xem trước bài học"
        description="Nội dung học viên sẽ thấy — chế độ chỉ đọc, không chấm điểm."
      />
      <Suspense fallback={<Skeleton className="h-[30rem] w-full" />}>
        <PreviewPage lessonId={id} />
      </Suspense>
    </div>
  );
}
