import { PageHeader } from "@/components/page-header";
import { ItemCreateForm } from "@/features/items/item-create-form";

export const metadata = { title: "Thêm vật phẩm — Dấu Việt CMS" };

export default function NewItemPage() {
  return (
    <div>
      <PageHeader
        title="Thêm vật phẩm thưởng"
        description="Vật phẩm học tập (mô hình / phiên bản số / huy hiệu) — không phải cổ vật thật."
      />
      <ItemCreateForm />
    </div>
  );
}
