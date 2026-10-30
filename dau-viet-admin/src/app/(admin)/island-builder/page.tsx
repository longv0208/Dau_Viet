import { PageGuideBanner } from "@/components/page-guide-banner";
import { PageHeader } from "@/components/page-header";
import { WorkspaceHubTabs } from "@/components/workspace-hub-tabs";
import { IslandLayoutList } from "@/features/island-builder/island-layout-list";

export const metadata = { title: "Quản lý Đảo Di Sản — Dấu Việt CMS" };

export default function IslandBuilderListPage() {
  return (
    <div>
      <WorkspaceHubTabs hub="island" />
      <PageHeader
        eyebrow="QUẢN TRỊ · ĐẢO DI SẢN"
        title="Quản lý Đảo Di Sản"
        description="Thiết kế bố cục đảo 2.5D, vùng đất theo cấp độ (Tier 1/2/3), vị trí các ô đặt vật phẩm và lớp cảnh quan."
      />
      <PageGuideBanner
        storageKey="island-builder"
        title="Đảo Di Sản 2.5D"
        purpose="Thiết kế bản đồ ô đất (slots) trên Đảo Di Sản nơi học viên trưng bày các vật phẩm trang trí và mô hình lịch sử đã mở khóa."
        appSurface="Hiển thị trực tiếp trên màn hình Đảo Di Sản cá nhân của học viên."
        nextStep="Sau khi xuất bản bố cục đảo, chuyển sang tab 'Cửa hàng Đảo Di Sản' để niêm yết giá các vật phẩm trang trí."
        links={[
          { href: "/island-shop", label: "Mở Cửa hàng Đảo Di Sản" },
          { href: "/items", label: "Danh mục Vật phẩm thưởng" },
        ]}
      />
      <IslandLayoutList />
    </div>
  );
}
