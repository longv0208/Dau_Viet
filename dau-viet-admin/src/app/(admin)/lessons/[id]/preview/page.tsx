import { PageHeader } from "@/components/page-header";
import { PreviewPage } from "@/features/lessons/preview/preview-page";

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
        title="Xem trước bài học"
        description="Nội dung học viên sẽ thấy — chế độ chỉ đọc, không chấm điểm."
      />
      <PreviewPage lessonId={id} />
    </div>
  );
}
