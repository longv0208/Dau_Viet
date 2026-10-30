import Link from "next/link";

import { PageGuideBanner } from "@/components/page-guide-banner";
import { PageHeader } from "@/components/page-header";
import { WorkspaceHubTabs } from "@/components/workspace-hub-tabs";
import { Button } from "@/components/ui/button";
import { ItemsTable } from "@/features/items/items-table";
import { ReconcilePanel } from "@/features/items/reconcile-panel";

export const metadata = { title: "Vật phẩm thưởng — Dấu Việt CMS" };

export default function ItemsPage() {
  return (
    <div>
      <WorkspaceHubTabs hub="island" />
      <PageHeader
        eyebrow="QUẢN TRỊ · VẬT PHẨM THƯỞNG"
        title="Vật phẩm thưởng"
        description="Danh mục mô hình, phiên bản số, huy hiệu và đồ trang trí Đảo Di Sản — luôn là vật phẩm học tập, không mô tả như cổ vật thật."
        actions={
          <Button asChild>
            <Link href="/items/new">+ Thêm vật phẩm</Link>
          </Button>
        }
      />
      <PageGuideBanner
        storageKey="items"
        title="Vật phẩm thưởng & Điều kiện mở khóa"
        purpose="Quản lý catalog vật phẩm và quy tắc tự động trao thưởng (Rule Builder) khi học viên hoàn thành bài học, sự kiện hoặc sưu tầm bằng chứng."
        appSurface="Hiển thị tại màn Kết quả bài học, Kho Sưu tập và cho phép đặt lên Đảo Di Sản (nếu bật 'Đặt lên đảo')."
        nextStep="Nhấn '+ Gắn vào bài học / sự kiện →' ở cột Điều kiện mở khóa để cấu hình tự động trao thưởng, hoặc đưa vật phẩm DECOR lên Cửa hàng Đảo."
        links={[
          { href: "/island-shop", label: "Cửa hàng Đảo Di Sản" },
          { href: "/island-builder", label: "Bố cục Đảo 2.5D" },
        ]}
      />
      <ItemsTable />
      <div className="mt-6">
        <ReconcilePanel />
      </div>
    </div>
  );
}
