import { Suspense } from "react";

import { PageHeader } from "@/components/page-header";
import { PublishPage } from "@/features/lessons/publish/publish-page";
import { Skeleton } from "@/components/ui/skeleton";

export const metadata = { title: "Xuất bản — Dấu Việt CMS" };

export default async function LessonPublishRoute({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return (
    <div>
      <PageHeader
        eyebrow="QUẢN TRỊ · XUẤT BẢN"
        title="Xuất bản bài học"
        description="Kiểm tra sẵn sàng và phát hành phiên bản mới cho học viên."
      />
      <Suspense fallback={<Skeleton className="h-96 w-full" />}>
        <PublishPage lessonId={id} />
      </Suspense>
    </div>
  );
}
