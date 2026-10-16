import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { EventsTable } from "@/features/events/events-table";

export const metadata = { title: "Sự kiện — Dấu Việt CMS" };

export default function EventsPage() {
  return (
    <div>
      <PageHeader
        title="Sự kiện"
        description="Danh sách sự kiện lịch sử trong hệ thống."
        actions={
          <Button disabled title="Sắp ra mắt">
            Tạo sự kiện
          </Button>
        }
      />
      <EventsTable />
    </div>
  );
}
