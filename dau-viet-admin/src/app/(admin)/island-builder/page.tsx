import { PageHeader } from "@/components/page-header";
import { IslandLayoutList } from "@/features/island-builder/island-layout-list";

export const metadata = { title: "Quản lý Đảo Di Sản — Dấu Việt CMS" };

export default function IslandBuilderListPage() {
  return (
    <div>
      <PageHeader
        title="Quản lý Đảo Di Sản"
        description="Thiết kế bố cục đảo 2.5D, vùng đất theo cấp độ (Tier 1/2/3), vị trí các ô đặt vật phẩm và lớp cảnh quan."
      />
      <IslandLayoutList />
    </div>
  );
}
