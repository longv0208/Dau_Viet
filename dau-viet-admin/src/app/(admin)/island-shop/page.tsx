import { PageGuideBanner } from "@/components/page-guide-banner";
import { WorkspaceHubTabs } from "@/components/workspace-hub-tabs";
import { IslandShopManager } from "@/features/island-shop/island-shop-manager";

export default function IslandShopPage() {
  return (
    <div>
      <WorkspaceHubTabs hub="island" />
      <PageGuideBanner
        storageKey="island-shop"
        title="Cửa hàng Đảo Di Sản"
        purpose="Chọn các vật phẩm có thuộc tính 'Đặt lên đảo' (placeable = true) từ Catalog để mở bán bằng Điểm Sử Ký."
        appSurface="Hiển thị trong Cửa hàng trên Đảo Di Sản của học viên."
        nextStep="Nếu chưa thấy vật phẩm cần bán, hãy tạo hoặc bật 'Có thể đặt lên Đảo Di Sản' trong mục Vật phẩm thưởng trước."
        links={[
          { href: "/items", label: "Quản lý Vật phẩm thưởng" },
          { href: "/island-builder", label: "Thiết kế Bố cục Đảo" },
        ]}
      />
      <IslandShopManager />
    </div>
  );
}
