import { Suspense } from "react";

import { PageHeader } from "@/components/page-header";
import { LessonWizard } from "@/features/lessons/lesson-wizard";

export const metadata = { title: "Tạo bài học — Dấu Việt CMS" };

export default function NewLessonPage() {
  return (
    <div>
      <PageHeader
        eyebrow="QUẢN TRỊ · BÀI HỌC"
        title="Tạo bài học mới"
        description="Hướng dẫn từng bước để soạn một bài học lịch sử."
      />
      <Suspense>
        <LessonWizard />
      </Suspense>
    </div>
  );
}
