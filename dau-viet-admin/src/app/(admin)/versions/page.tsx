import Link from "next/link";

import { PageHeader } from "@/components/page-header";
import { EmptyState } from "@/components/empty-state";
import { Button } from "@/components/ui/button";

export const metadata = { title: "Phiên bản — Dấu Việt CMS" };

/**
 * Honest empty state — backend exposes versions per-lesson only
 * (/admin/lessons/{id}/versions), so there is no global version list to show.
 */
export default function VersionsPage() {
  return (
    <div>
      <PageHeader title="Phiên bản" />
      <EmptyState
        title="Chọn một bài học để xem lịch sử phiên bản"
        description="Mỗi lần xuất bản tạo một phiên bản bất biến. Mở một bài học cụ thể để xem toàn bộ phiên bản của nó."
        action={
          <Button asChild variant="secondary">
            <Link href="/lessons">Đến danh sách bài học</Link>
          </Button>
        }
      />
    </div>
  );
}
