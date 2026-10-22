import Link from "next/link";

import { PageHeader } from "@/components/page-header";
import { Button } from "@/components/ui/button";
import { ItemsTable } from "@/features/items/items-table";
import { RewardBackfillButton } from "@/features/items/reward-backfill-button";

export const metadata = { title: "Vật phẩm thưởng — Dấu Việt CMS" };

export default function ItemsPage() {
  return (
    <div>
      <PageHeader
        title="Vật phẩm thưởng"
        description="Danh mục mô hình, phiên bản số và huy hiệu học viên mở khóa được — luôn là vật phẩm học tập, không phải cổ vật thật."
        actions={
          <Button asChild>
            <Link href="/items/new">+ Thêm vật phẩm</Link>
          </Button>
        }
      />
      <ItemsTable />
      <div className="mt-6">
        <RewardBackfillButton />
      </div>
    </div>
  );
}
