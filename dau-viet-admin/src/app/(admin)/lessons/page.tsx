import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { LessonsTable } from "@/features/lessons/lessons-table";

export const metadata = { title: "Bài học — Dấu Việt CMS" };

export default function LessonsPage() {
  return (
    <div>
      <PageHeader
        title="Bài học"
        description="Danh sách bài học và trạng thái xuất bản."
        actions={
          <Button disabled title="Sắp ra mắt">
            Tạo bài học
          </Button>
        }
      />
      <LessonsTable />
    </div>
  );
}
