import { PageGuideBanner } from "@/components/page-guide-banner";
import { PageHeader } from "@/components/page-header";
import { AssetsLibrary } from "@/features/assets/assets-library";

export const metadata = { title: "Thư viện media — Dấu Việt CMS" };

export default function AssetsPage() {
  return (
    <div>
      <PageHeader
        eyebrow="QUẢN TRỊ · KHO DÙNG CHUNG · THƯ VIỆN MEDIA"
        title="Thư viện media"
        description="Quản lý hình ảnh, bản đồ và tư liệu số dùng chung cho toàn bộ sự kiện, bài học và vật phẩm."
      />
      <PageGuideBanner
        storageKey="assets"
        title="Thư viện Media dùng chung"
        purpose="Lưu trữ tập trung ảnh bìa sự kiện, ảnh tư liệu bằng chứng, ảnh địa điểm di tích và biểu tượng vật phẩm thưởng."
        appSurface="Phục vụ hiển thị hình ảnh trên toàn bộ màn hình của ứng dụng học viên."
        nextStep="Tải ảnh lên đây trước hoặc tải trực tiếp trong biểu mẫu Sự kiện / Bằng chứng / Vật phẩm."
        links={[
          { href: "/events", label: "Sự kiện" },
          { href: "/evidence", label: "Bằng chứng" },
          { href: "/items", label: "Vật phẩm thưởng" },
        ]}
      />
      <AssetsLibrary />
    </div>
  );
}
