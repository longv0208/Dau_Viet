import { PageHeader } from "@/components/page-header";
import { PublishPage } from "@/features/lessons/publish/publish-page";

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
        title="Xuất bản bài học"
        description="Kiểm tra sẵn sàng và phát hành phiên bản mới cho học viên."
      />
      <PublishPage lessonId={id} />
    </div>
  );
}
