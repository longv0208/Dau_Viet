import { PageHeader } from "@/components/page-header";
import { AssetsLibrary } from "@/features/assets/assets-library";

export const metadata = { title: "Thư viện media — Dấu Việt CMS" };

export default function AssetsPage() {
  return (
    <div>
      <PageHeader
        eyebrow="QUẢN TRỊ · THƯ VIỆN MEDIA"
        title="Thư viện media"
        description="Quản lý ảnh và tư liệu dùng trong các bài học."
      />
      <AssetsLibrary />
    </div>
  );
}
