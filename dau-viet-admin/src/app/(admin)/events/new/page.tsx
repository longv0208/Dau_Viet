import { PageHeader } from "@/components/page-header";
import { EventForm } from "@/features/events/event-form";

export const metadata = { title: "Tạo sự kiện — Dấu Việt CMS" };

export default function NewEventPage() {
  return (
    <div>
      <PageHeader
        eyebrow="QUẢN TRỊ · SỰ KIỆN"
        title="Tạo sự kiện"
        description="Thêm một sự kiện lịch sử mới vào hệ thống."
      />
      <EventForm />
    </div>
  );
}
