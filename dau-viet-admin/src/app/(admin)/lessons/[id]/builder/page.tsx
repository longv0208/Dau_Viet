import { PageHeader } from "@/components/page-header";
import { BuilderPage } from "@/features/lessons/builder/builder-page";

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
      <BuilderPage lessonId={id} />
    </div>
  );
}
