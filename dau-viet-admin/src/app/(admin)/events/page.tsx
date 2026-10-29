import Link from "next/link";

import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { EventsTable } from "@/features/events/events-table";

export const metadata = { title: "Sự kiện — Dấu Việt CMS" };

export default function EventsPage() {
  return (
    <div>
      <PageHeader
        eyebrow="QUẢN TRỊ · SỰ KIỆN"
        title="Sự kiện"
        description="Danh sách sự kiện lịch sử trong hệ thống."
        actions={
          <Button asChild>
            <Link href="/events/new">Tạo sự kiện</Link>
          </Button>
        }
      />
      <EventsTable />
    </div>
  );
}
