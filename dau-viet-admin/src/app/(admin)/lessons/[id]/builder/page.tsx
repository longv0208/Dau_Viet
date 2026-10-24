import { Suspense } from "react";

import { PageHeader } from "@/components/page-header";
import { BuilderPage } from "@/features/lessons/builder/builder-page";
import { Skeleton } from "@/components/ui/skeleton";

export const metadata = { title: "Soạn bài học — Dấu Việt CMS" };

export default async function LessonBuilderRoute({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return (
    <div>
      <PageHeader
        title="Soạn giai đoạn & hoạt động"
        description="Xây dựng cấu trúc bài học trực quan — lưu vào bản nháp."
      />
      <Suspense fallback={<Skeleton className="h-[28rem] w-full" />}>
        <BuilderPage lessonId={id} />
      </Suspense>
    </div>
  );
}
