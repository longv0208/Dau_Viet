import { PageHeader } from "@/components/page-header";
import { LessonBasicEditor } from "@/features/lessons/lesson-basic-form";

export const metadata = { title: "Bài học — Dấu Việt CMS" };

export default async function LessonDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return (
    <div>
      <PageHeader title="Bài học" description="Thông tin cơ bản và trạng thái xuất bản." />
      <LessonBasicEditor lessonId={id} />
    </div>
  );
}
