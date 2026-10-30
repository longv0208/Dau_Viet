import Link from "next/link";

import { PageGuideBanner } from "@/components/page-guide-banner";
import { PageHeader } from "@/components/page-header";
import { WorkspaceHubTabs } from "@/components/workspace-hub-tabs";
import { Button } from "@/components/ui/button";
import { LessonsTable } from "@/features/lessons/lessons-table";

export const metadata = { title: "Bài học — Dấu Việt CMS" };

export default function LessonsPage() {
  return (
    <div>
      <WorkspaceHubTabs hub="event-children" />
      <PageHeader
        eyebrow="QUẢN TRỊ · NHÁNH CON SỰ KIỆN · BÀI HỌC"
        title="Bài học điều tra lịch sử"
        description="Danh sách toàn bộ bài học thuộc các sự kiện và trạng thái xuất bản."
        actions={
          <Button asChild>
            <Link href="/lessons/new">+ Tạo bài học</Link>
          </Button>
        }
      />
      <PageGuideBanner
        storageKey="lessons"
        title="Bài học"
        purpose="Biên tập kịch bản học tập theo 4 giai đoạn tư duy lịch sử (Bối cảnh → Khám phá → Suy luận → Kết luận CER) gắn với từng Sự kiện."
        appSurface="Render trực tiếp trong Sổ tay Thám tử Lịch sử (Lesson Player) trên ứng dụng học viên."
        nextStep="Khuyến khích mở Không gian Sự kiện để soạn bài học đúng ngữ cảnh, sau đó kiểm tra và xuất bản phiên bản mới."
        links={[
          { href: "/events", label: "Mở từ Sự kiện" },
          { href: "/templates", label: "Mẫu bài học" },
          { href: "/versions", label: "Lịch sử Phiên bản" },
        ]}
      />
      <LessonsTable />
    </div>
  );
}
