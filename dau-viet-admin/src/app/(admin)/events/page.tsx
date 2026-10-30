import Link from "next/link";

import { PageGuideBanner } from "@/components/page-guide-banner";
import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { EventsTable } from "@/features/events/events-table";

export const metadata = { title: "Sự kiện — Dấu Việt CMS" };

export default function EventsPage() {
  return (
    <div>
      <PageHeader
        eyebrow="QUẢN TRỊ · SỰ KIỆN"
        title="Sự kiện lịch sử"
        description="Không gian biên tập trung tâm: mỗi sự kiện quản lý trọn gói bài học, bằng chứng, hoạt họa, hồ sơ và địa điểm di tích."
        actions={
          <Button asChild>
            <Link href="/events/new">+ Tạo sự kiện</Link>
          </Button>
        }
      />
      <PageGuideBanner
        storageKey="events"
        title="Không gian Sự kiện"
        purpose="Quản lý danh sách sự kiện lịch sử. Nhấn 'Mở không gian →' ở từng dòng để soạn bài học, bằng chứng, hoạt họa và cấu hình phần thưởng ngay trong sự kiện đó."
        appSurface="Hiển thị thành các mốc sự kiện trên màn Hành trình Lịch sử (/journey) và chi tiết chiến dịch điều tra của học viên."
        nextStep="Sau khi tạo và xuất bản sự kiện cùng bài học, hãy xếp sự kiện vào chương thời kỳ trên Bản đồ Dấu Ấn."
        links={[
          { href: "/learning-path", label: "Bản đồ Dấu Ấn" },
          { href: "/map-locations", label: "Địa điểm di tích" },
        ]}
      />
      <EventsTable />
    </div>
  );
}
